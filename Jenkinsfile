pipeline {
    agent { label 'lint' }

    stages {
        stage('Lint') {
            steps {
                sh 'make lint'
            }
        }
    }
}
