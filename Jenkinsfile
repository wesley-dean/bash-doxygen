pipeline {
    agent { label 'docker' }

    stages {
        stage('Lint') {
            steps {
                sh 'make lint'
            }
        }
    }
}
