ubuntu:
	docker run -it -v ${PWD}:/test ubuntu:latest /test/install.sh

debian:
	docker run -it -v ${PWD}:/test debian:latest /test/install.sh

centos:
	docker run -it -v ${PWD}:/test centos:7 /test/install.sh

test: ubuntu debian centos