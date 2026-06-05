pipeline {
    agent any

    environment {
        IMAGE = "ttl.sh/albertolg101:2h"
        DOCKER_DEPLOY_HOST = "docker"
        TARGET_DEPLOY_HOST = "target"
        ANSIBLE_HOST_KEY_CHECKING = "False"
        KUBE_ARGS = '--server=https://kubernetes:6443 --insecure-skip-tls-verify=true'
    }

    stages {
        stage('Test') {
            steps {
                sh "docker build --target test -t ${IMAGE}-test ."
            }
        }

        stage('Build') {
            steps {
                sh "docker build --target prod -t ${IMAGE} ."
            }
        }

        stage('Push') {
            steps {
                sh "docker push ${IMAGE}"
            }
        }

        stage('Deploy') {
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'docker-ssh-key',
                    keyFileVariable: 'SSH_KEY',
                    usernameVariable: 'SSH_USER'
                )]) {
                    sh 'ansible-playbook -i "$DOCKER_DEPLOY_HOST," --private-key=$SSH_KEY --user=$SSH_USER -e image=$IMAGE docker-playbook.yml'
                }
            }
        }

        stage('Deploy: Target') {
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'target-ssh-key',
                    keyFileVariable: 'TARGET_SSH_KEY',
                    usernameVariable: 'TARGET_SSH_USER'
                )]) {
                    sh 'ansible-playbook -i "$TARGET_DEPLOY_HOST," --private-key="$TARGET_SSH_KEY" --user="$TARGET_SSH_USER" target-playbook.yml'
                }
            }
        }

        stage('Deploy: Kubernetes') {
            steps {
                withCredentials([string(credentialsId: 'k8s-token', variable: 'K8S_TOKEN')]) {
                    sh '''
                        kubectl ${KUBE_ARGS} --token="$K8S_TOKEN" delete pod myapp --ignore-not-found=true
                        kubectl ${KUBE_ARGS} --token="$K8S_TOKEN" apply -f k8s/pod.yaml
                        kubectl ${KUBE_ARGS} --token="$K8S_TOKEN" apply -f k8s/service.yaml
                        kubectl ${KUBE_ARGS} --token="$K8S_TOKEN" wait --for=condition=Ready pod/myapp --timeout=120s
                    '''
                }
            }
        }
    }
}
