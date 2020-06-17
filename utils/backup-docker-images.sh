#!/bin/bash
docker commit --author "Fabrizio Torelli (fabrizio.torelli@optiim.com)" --message "Live Optiim Jenkins Image" jenkins registry.gitlab.com/aangine/kubernetes/aangine-service-docker-images/jenkins/qa:latest
docker login -u fabrizio.torelli -p rZGnTyBPoRM3aWqy9wwk registry.gitlab.com
docker push registry.gitlab.com/aangine/kubernetes/aangine-service-docker-images/jenkins/qa:latest
docker rmi registry.gitlab.com/aangine/kubernetes/aangine-service-docker-images/jenkins/qa:latest
docker commit --author "Fabrizio Torelli (fabrizio.torelli@optiim.com)" --message "Live Optiim Jenkins Nginx Image" nginx registry.gitlab.com/aangine/kubernetes/aangine-service-docker-images/jenkins-nginx/qa:latest
docker push registry.gitlab.com/aangine/kubernetes/aangine-service-docker-images/jenkins-nginx/qa:latest
docker rmi registry.gitlab.com/aangine/kubernetes/aangine-service-docker-images/jenkins-nginx/qa:latest
docker logout
