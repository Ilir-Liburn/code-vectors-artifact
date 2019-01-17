SHELL=/bin/bash

# Cross-platform realpath from 
# https://stackoverflow.com/a/18443300
# NOTE: Adapted for Makefile use
define BASH_FUNC_realpath%%
() {
  OURPWD=$PWD
  cd "$(dirname "$1")"
  LINK=$(readlink "$(basename "$1")")
  while [ "$LINK" ]; do
    cd "$(dirname "$LINK")"
    LINK=$(readlink "$(basename "$1")")
  done
  REALPATH="$PWD/$(basename "$1")"
  cd "$OURPWD"
  echo "$REALPATH"
}
endef
export BASH_FUNC_realpath%%

ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

.PHONY: help
.PHONY: submodules
.PHONY: c2ocaml
.PHONY: lsee
.PHONY: glove
.PHONY: learn-vectors-redis
.PHONY: end-to-end-redis
.PHONY: end-to-end-nginx
.PHONY: end-to-end-hexchat
.PHONY: end-to-end-nmap
.PHONY: end-to-end-curl
.PHONY: rq4-generate-data

.DEFAULT_GOAL := help

help: ## This help.
	@grep -E \
		'^[\/\.0-9a-zA-Z_-]+:.*?## .*$$' \
		$(MAKEFILE_LIST) \
		| grep -v '<HIDE FROM HELP>' \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "}; \
		       {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

submodules: ## Ensures that submodules are setup.
	git submodule init
	git submodule update --remote

c2ocaml: submodules ## Ensures that c2ocaml is cloned and setup.
	@echo "[code-vectors] Ensuring that we have c2ocaml"
	docker pull jjhenkel/c2ocaml

lsee: submodules ## Ensures that the lsee is cloned and setup.
	@echo "[code-vectors] Ensuring we have lsee"
	docker pull jjhenkel/lsee

glove: ## Ensures that the GloVe tool is pulled from docker hub.
	@echo "[code-vectors] Ensuring we have GloVe"
	docker pull jjhenkel/glove

learn-vectors-redis: glove ## Learns GloVe vectors from redis trace corpus and runs demo (using Gensim).
	@echo "[code-vectors] Learning vectors for traces generated from redis..."
	docker run -it --rm \
	  -v ${ROOT_DIR}/lsee:/traces \
		-v ${ROOT_DIR}/artifacts/redis:/output \
		jjhenkel/glove \
		/traces/redis.traces.txt 10 15 300 50
	@echo "[code-vectors] Learner finished. Output saved in ${ROOT_DIR}/artifacts/redis"
	@echo "[code-vectors] Running demo using Gensim and our freshly learned vectors..."
	docker run -it --rm \
		-v ${ROOT_DIR}/artifacts:/artifacts \
		--entrypoint python \
		jjhenkel/glove \
		/app/redis-demo.py
	@echo "[code-vectors] Demo complete."

end-to-end-redis: lsee c2ocaml ## Runs the toolchain end-to-end on redis.
	@echo "[code-vectors] Running end-to-end pipeline on redis..."
	@echo "[code-vectors] Transforming sources..."
	pushd ${ROOT_DIR}/c2ocaml ; make redis ; popd
	@echo "[code-vectors] Generating traces..."
	pushd ${ROOT_DIR}/lsee ; make redis ; popd
	@echo "[code-vectors] Collecting traces..."
	pushd ${ROOT_DIR}/lsee ; NAME=redis make collect ; popd
	@echo "[code-vectors] Completed end-to-end run on redis!"
	@echo "[code-vectors] Run make learn-vectors-redis to learn vectors using GloVe!"

end-to-end-linux: lsee c2ocaml ## Runs the toolchain end-to-end on linux.
	@echo "[code-vectors] Running end-to-end pipeline on redis..."
	@echo "[code-vectors] Transforming sources..."
	pushd ${ROOT_DIR}/c2ocaml ; make linux ; popd
	@echo "[code-vectors] Generating traces..."
	pushd ${ROOT_DIR}/lsee ; make linux ; popd
	@echo "[code-vectors] Collecting traces..."
	pushd ${ROOT_DIR}/lsee ; NAME=linux make collect ; popd
	@echo "[code-vectors] Completed end-to-end run on linux!"
	@echo "[code-vectors] Run make learn-vectors-linux to learn vectors using GloVe!"

learn-vectors-linux: glove ## Learns GloVe vectors from linux trace corpus and runs demo (using Gensim).
	@echo "[code-vectors] Learning vectors for traces generated from linux..."
	docker run -it --rm \
	  -v ${ROOT_DIR}/lsee:/traces \
		-v ${ROOT_DIR}/artifacts/linux:/output \
		jjhenkel/glove \
		/traces/linux.traces.txt 10 15 300 100
	@echo "[code-vectors] Learner finished. Output saved in ${ROOT_DIR}/artifacts/linux"

end-to-end-nginx: lsee c2ocaml  ## Runs the toolchain end-to-end on nginx <HIDE FROM HELP>.
	@echo "[code-vectors] Running end-to-end pipeline on nginx..."

end-to-end-hexchat: lsee c2ocaml ## Runs the toolchain end-to-end on curl <HIDE FROM HELP>.
	@echo "[code-vectors] Running end-to-end pipeline on hexchat..."

end-to-end-nmap: lsee c2ocaml ## Runs the toolchain end-to-end on nmap <HIDE FROM HELP>.
	@echo "[code-vectors] Running end-to-end pipeline on nmap..."

end-to-end-curl: lsee c2ocaml ## Runs the toolchain end-to-end on curl <HIDE FROM HELP>.
	@echo "[code-vectors] Running end-to-end pipeline on curl..."

rq4-generate-data: lsee c2ocaml ## Generates data to run RQ4 <HIDE FROM HELP>.
	@echo "[code-vectors] Generating data for RQ4..."
	@echo "[code-vectors] Transforming sources..."
	pushd ${ROOT_DIR}/c2ocaml ; make rq4 ; popd
	@echo "[code-vectors] Generating traces..."
	pushd ${ROOT_DIR}/lsee ; make rq4 ; popd
	mv ${ROOT_DIR}/lsee/rq4-good.traces.txt ${ROOT_DIR}/reproduce/rq4/good.traces.txt
	mv ${ROOT_DIR}/lsee/rq4-bad.traces.txt ${ROOT_DIR}/reproduce/rq4/bad.traces.txt
	@echo "[code-vectors] Generating dataset..."
	docker build -t jjhenkel/code-vectors-artifact:rq4-gen -f ${ROOT_DIR}/reproduce/rq4/Dockerfile ${ROOT_DIR}/reproduce/rq4 
	docker run -it --rm jjhenkel/code-vectors-artifact:rq4-gen &> ${ROOT_DIR}/reproduce/rq4/dataset.txt
	@echo "[code-vectors] Finished!"
