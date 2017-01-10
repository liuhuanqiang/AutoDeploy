#/bin/bash
read -p "image from : " Aimage

echo "remove old vp container"
quiet=`docker rm -f vp`
quiet=`docker ps -a |grep dev | awk '{print $2}'|xargs docker rm`

echo "remove old image"
quiet=`docker rmi hyperledger/fabric-peer:latest`
quiet=`docker rmi hyperledger/fabric-baseimage:latest`
quiet=`docker images|grep dev|awk '{print $1}'|xargs docker rmi`

echo "run temp container"
containerID=`docker run -idt $Aimage`

echo "copy folder"
docker cp ./mychaincode $containerID:/opt/gopath/src/github.com/mychaincode

echo "commit temp container"
newimageID=`docker commit $containerID|cut -d : -f 2`

echo "remove temp container"
quiet=`docker rm -f $containerID`

echo "tag to new image"
quiet=`docker tag $newimageID hyperledger/fabric-peer:latest`
quiet=`docker tag $newimageID hyperledger/fabric-baseimage:latest`



echo "run hyperledger/fabric-peer:latest"
containerID=`docker run -idt -p 7050:7050 -p 7051:7051 --name=vp \
-v /var/run/docker.sock:/var/run/docker.sock \
-e CORE_VM_ENDPOINT=unix:///var/run/docker.sock \
hyperledger/fabric-peer:latest`
echo "the new image ID :" $containerID

#CORE_PEER_ADDRESS="$peerIP":7051 
echo "run peer node"
peerIP=`docker exec -it $containerID ifconfig |grep Bcast | awk '{print $2}' | sed 's/addr://'|sed 's/\./\\./g'`
docker exec  $containerID /bin/bash -c "export CORE_PEER_ADDRESS="$peerIP":7051 && peer node start" &

read 
while ((1))
do
	read -p "In ./mychaincode,which directory to deploy ? :" deploydirectory
	
	if [ "${deploydirectory}" == "" ] ;then continue ; fi
		read -p "what do you use lang (golang) : " lang
	if [ "${lang}" == "" ] ;then continue ; fi
		read -p "deploy parameter \"Function\" : " function
		read -p "deploy parameter \"Args\" : " args
	if [ "${lang}" == "java" ] ; then
		#JAVA lang run here
		docker exec -it $containerID /bin/bash -c "peer chaincode deploy \\
		-l java \\
		-p ../../mychaincode/$deploydirectory \\
		-c '{\"Function\":\""$function"\",\"Args\":["$args"]}'";
	else
		#GO lang run here
		docker exec -it $containerID peer chaincode deploy  \
		-p github.com/mychaincode/$deploydirectory \
		-c '{"Function":"'$function'", "Args": ['$args']}';
	fi
done

