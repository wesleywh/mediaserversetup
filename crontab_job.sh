if [ $(sudo docker images -f "dangling=true" -q | wc -l) -gt 0 ]; then
	sudo docker rmi $(sudo docker images -f "dangling=true" -q)
fi