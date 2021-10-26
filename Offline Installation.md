# Offline Installation

This page covers the details for downloading the Kasten K10 containers to a locally hosted registry within a existing MiniKube profile (Kubernetes Cluster). Ensuring you have the images available for an internet restricted (Air-Gap) installation of Kasten.

To be prepared for an offline installation, at a minimum you need to have docker client with the MiniKube images, and run the Kasten offline tool to grab the images to the Docker Client, and finally download a copy of the Helm Chart for Kasten K10. This work is based on [this blog post](https://veducate.co.uk/kasten-air-gap/). 

## Pre Reqs

- minikube - https://minikube.sigs.k8s.io/docs/start/ 
- helm - https://helm.sh/docs/intro/install/
- kubectl - https://kubernetes.io/docs/tasks/tools/ 

Container or virtual machine manager, such as: Docker, Hyperkit, Hyper-V, KVM, Parallels, Podman, VirtualBox, or VMware

I would also suggest that we need bash which means the advice for Windows users is install Git bash but for best experience use WSL 

For the above pre-reqs I use Arkade (https://github.com/alexellis/arkade) 

```
arkade get minikube helm kubectl
```

## Install MiniKube

Run the following command:
````
minikube start --addons volumesnapshots,csi-hostpath-driver,registry --apiserver-port=6443 --container-runtime=containerd -p offline-demo --kubernetes-version=1.21.2 --nodes=2
````
````
    Note: Minikube will generate a port and request you use that port when enabling registry. That instruction is not related to this guide.
````

## Configure Docker for connectivity to the MiniKube Internal Cluster Image Registry

When enabled, the MiniKube registry addon exposes its port 5000 on the minikube’s virtual machine.

Open a new terminal window to run the following commands. The following [instructions](https://minikube.sigs.k8s.io/docs/handbook/registry/#docker-on-macos) for are Docker on Mac OS X, for other Operating Systems please see [this guide](https://minikube.sigs.k8s.io/docs/handbook/registry/).

In order to make docker accept pushing images to this registry, we have to redirect port 5000 on the docker virtual machine over to port 5000 on the minikube machine. We can (ab)use docker’s network configuration to instantiate a container on the docker’s host, and run socat there:
````
docker run --rm -it --network=host alpine ash -c "apk add socat && socat TCP-LISTEN:5000,reuseaddr,fork TCP:$(minikube ip):5000"
````
![image](https://user-images.githubusercontent.com/22192242/138969744-e0c488c4-42a5-4df5-b0da-3af4a80a8358.png)

Once socat is running it’s possible to push images to the minikube registry:
````
docker tag my/image localhost:5000/myimage
docker push localhost:5000/myimage
````
After the image is pushed, refer to it by localhost:5000/{name} in kubectl specs.

![image](https://user-images.githubusercontent.com/22192242/138969829-06625c0b-496b-4558-accc-30c77ccddbdf.png)

## Download the Kasten K10 Container Images

In your main terminal window, not the one you used for the docker redirect in the last step, run the following command:
````
docker run --rm -ti -v /var/run/docker.sock:/var/run/docker.sock \
    -v ${HOME}/.docker:/root/.docker \
    gcr.io/kasten-images/k10offline:4.5.1 pull images --newrepo localhost:5000
````
This will download all the images to Docker Client, then push into your Repository which we setup inside of MiniKube. You can run the same command without the final argument ````--newrepo```` and this will just download the images to your docker client. 

![image](https://user-images.githubusercontent.com/22192242/138971571-ed24951e-7ba3-4cd7-8fb0-6209b5e0af06.png)

## Download the Helm Chart for offline use

Run the following command:
````
helm repo update && \ 
    helm fetch kasten/k10 --version=4.5.1
````
![image](https://user-images.githubusercontent.com/22192242/138971723-32912697-3eff-493f-b806-8f8fe6658a7a.png)

## Install Kasten K10 with a local Helm Chart and Container Images

Create the namespace:
````
kubectl create namespace kasten-io
````
Then run the following Helm command:
````
helm install k10 k10-4.5.1.tgz --namespace kasten-io \
--set global.airgapped.repository=localhost:5000
````

![image](https://user-images.githubusercontent.com/22192242/138971836-bc198c49-b16a-4c0c-999d-6275484bfbda.png)

![image](https://user-images.githubusercontent.com/22192242/138972045-1621e0ba-1153-4912-bb0f-13a9d32b4e50.png)

## Continue the setup following the main guide

[Continue by following the main guide](../readme.md#mysql)
