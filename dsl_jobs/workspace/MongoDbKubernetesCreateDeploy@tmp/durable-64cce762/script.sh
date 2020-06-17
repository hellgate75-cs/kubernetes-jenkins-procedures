
                        #!/bin/bash
                        dos2unix /var/lib/jenkins/continuousdelivery/kubernetes-jenkins-procedures/provision-k8s-cluster.sh
                        chmod +x /var/lib/jenkins/continuousdelivery/kubernetes-jenkins-procedures/provision-k8s-cluster.sh
                        bash -c "/var/lib/jenkins/continuousdelivery/kubernetes-jenkins-procedures/provision-k8s-cluster.sh CS-MongoDb-Cluster AangineDemo1Instance qa-aangine-demo1-apps-namespace . 0 . . aangine-mongo true aangineQA11Oct2019202004221516"
                        