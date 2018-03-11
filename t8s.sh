#/usr/bin/env bash


HL="======================================="

scale() {
    local -r projectName="$1" appName="$2" 
    local replicas="$3"
    
    echo
    echo "We are scaling your application to $replicas replicas..."
    echo

    replicas=$(($replicas))
    
    gcloud config set project $projectName
    gcloud config set compute/zone us-central1-b


    kubectl scale deployment "${appName}" --replicas=$replicas

    echo
    echo "Try the command: <k get po> to check your pods."
    echo

}

update() {
    local -r projectName="$1" appName="$2" version="$3"
    
    # time=$(date +%Y%m%d%H%M%S | base64)
    # version=$time
    echo
    echo "We are updating your application to version: $version."
    echo

    gcloud config set project $projectName
    gcloud config set compute/zone us-central1-b

    $(which docker) build -t gcr.io/${projectName}/${appName}:${version} <put your current directory here>
    #yes | docker system prune

    gcloud docker -- push gcr.io/${projectName}/${appName}

    currentImage=$(yq r <path to yaml file> spec.template.spec.containers[0].image)
    currentVersion=$(echo $currentImage | awk -F":" '{print $NF}')

    sed -i -e 's/'${currentVersion}'/'${version}'/g' <path to yaml file>
    
    kubectl set image deployments/${appName} ${appName}=gcr.io/${projectName}/${appName}:${version}

    sleep 5
    echo "Your deployment has been updated! Do you want to run a curl to test it? (say yes)"
}

deployToGCP() {
    local -r projectName="$1" appName="$2" numPods="$3" appVersion="$4" numNodes="$5"

    gcloud config set project $projectName
    gcloud config set compute/zone us-central1-b

    echo
    echo "Building docker image..."
    echo

    $(which docker) build -t gcr.io/${projectName}/${appName}:${appVersion} .
    yes | docker system prune

    echo
    echo "Pushing docker image..."
    echo

    gcloud docker -- push gcr.io/${projectName}/${appName}:${appVersion}

    exists=$(gcloud container clusters list --format="json" | jq '.[] | select(.name=="'${appName}'")')

    if [ -z "$exists" ];
    then
        echo
        echo "Cluster does not exist, creating cluster..."
        echo
        gcloud container clusters create "${appName}" --num-nodes=${numNodes};
        echo
        kubectl run "${appName}" --image=gcr.io/${projectName}/${appName}:${appVersion} --port 8080;
        echo
        kubectl expose deployment "${appName}" --type=LoadBalancer --port 80 --target-port 8080;
        echo
    else
        echo
        echo "Cluster already exists, getting credentials..."
        echo
        gcloud container clusters get-credentials "${appName}";

        deployExists=$(kubectl get deploy -o json | jq -r '.items[] | select(.metadata.name=="'${appName}'")');
        if [ -z "$deployExists" ];
        then
            echo
            echo "Creating new deployment on cluster ${appName}..."
            echo  
            kubectl run "${appName}" --image=gcr.io/${projectName}/${appName}:${appVersion} --port 8080;
            echo
            kubectl expose deployment "${appName}" --type=LoadBalancer --port 80 --target-port 8080;
            echo
        else
            echo
            echo "Deployment already exists..."
            echo "Scaling deployment..."
            echo
            kubectl scale deployment "${appName}" --replicas=$numPods;
            echo
            ip=$(kubectl get service -o json | jq -r '.items[] | select(.spec.type=="LoadBalancer") | .status.loadBalancer.ingress[].ip');
            
            echo "Testing deployment..."
            curl $ip
            echo
        fi
    fi

    echo
    echo $HL
    echo
    echo "Congrats! Your app is now deployed on Google Kubernetes Engine."
    echo
    echo $HL
    echo
    echo "Let's check out our deployment: Text the word 'test' to the number +1 (310) 494-2815"
    echo
    echo 


}

rollback() {

    appName=$(kubectl get deploy -o json | jq -r '.items[].metadata.name');


    echo
    echo "Rolling back deployment: deployments/$appName..."
    echo

    kubectl rollout undo deployments ${appName} &
    ID=$!
    echo $ID
    sleep 5

    echo
    echo "Successfully rolled back...Do you want to test? (say yes)"
    kill $ID
    exit 0
    # echo "Checking endpoint..."
    # echo

    # sleep 5

    # ip=$(kubectl get service -o json | jq -r '.items[] | select(.spec.type=="LoadBalancer") | .status.loadBalancer.ingress[].ip');
        
    # curl $ip;
    # echo




}


main() {
    local -r appType="$1" cloudType="$2" projectName="$3" appName="$4" numPods="$5" appVersion="$6" numNodes="$7"

    echo $HL
    echo
    echo "This is the appType: "$appType  
    echo "This is the cloudType: "$cloudType
    echo "This is the projectName: "$projectName
    echo "This is the appName: "$appName
    echo "This is the numPods: "$numPods
    echo "This is the appVersion: "$appVersion
    echo "This is the numNodes: "$numNodes
    echo
    echo $HL
    echo

    cat <<EOF > Dockerfile
FROM node:carbon

# Create app directory
WORKDIR /usr/src/app

# Install app dependencies
# A wildcard is used to ensure both package.json AND package-lock.json are copied
# where available (npm@5+)
COPY package*.json ./

RUN npm install
# If you are building your code for production
# RUN npm install --only=production

# Bundle app source
COPY . .

EXPOSE 8080
CMD [ "npm", "start" ]
EOF


echo "Setting config now..."
echo

    deployToGCP "$projectName" "$appName" "$numPods" "$appVersion" "$numNodes"
}

help() {
    echo
    echo $HL
    echo
    echo "Here is some help my fellow helsman:"
    echo
    echo "t8s just : us this to just do one thing. You can do: "
    echo "         scale     :  <projectName> <appName> <numPods>"
    echo "         update    :  <projectName> <appName> "
    echo "         rollback  :  <please> "
    echo
    echo $HL
    echo
    echo "Here are some example commands: "
    echo
    echo "t8s just scale hacktech-t8s hello-world-node 5"
    echo "t8s just update hacktech-t8s hello-world-node"
    echo "t8s just rollback please"
    echo
    echo $HL
    echo
    echo "Additionally, these are the basic commands: "
    echo
    echo "t8s init : starts your project"
    echo "t8s help : get some help"
    echo
    echo $HL
}

version=$(date +%Y%m%d%H%M%S | base64)

command=${1}

if [ -n "$command" ] && [[ "$command" == "just" ]];
then

    function=${2}

    if [ -z "$function" ];
    then
        echo "Please enter which function you would like to use."
        echo "Here are the options: "
        echo
        echo "scale"
        echo "update"
        echo "rollback"
        echo
        echo
        read -p "Your function: " function
    fi
    if [ -z "$function" ];
    then
        echo "You need to enter a function. Try again later."
        exit 1
    fi

    echo "You want to $function your ish. OK!"

    if [[ "$function" == "scale" ]];
    then
        if [ -z "$3" ];
        then
            read -p "Which project is this for? " projectName
        else
            projectName="$3"
        fi
        if [ -z "$4" ];
        then
            read -p "Which app is this for? " appName
        else
            appName="$4"
        fi
        if [ -z "$5" ];
        then
            read -p "How many replicas do you want? " replicas
        else
            replicas="$5"
        fi
        scale "$projectName" "$appName" "$replicas"
    fi

    if [[ "$function" == "update" ]];
    then
        if [ -z "$3" ];
        then
            read -p "Which project is this for? " projectName
        else
            projectName="$3"
        fi
        if [ -z "$4" ];
        then
            read -p "Which app is this for? " appName
        else
            appName="$4"
        fi
        if [ -z "$version" ];
        then
            read -p "What version do you want? " version
        fi
        update "$projectName" "$appName" "$version"
    fi

    if [[ "$function" == "rollback" ]];
    then
        if [ -z "$3" ];
        then
            read -p "Use your manners: " please
        else
            please="$3"
        fi
        if [[ "$please" != "please" ]];
        then
            echo "Be nice. Say please"
            exit 0
        fi
        rollback
    fi

fi

if [[ -n "$command" ]] && [[ "$command" == "init" ]];
then

    echo $HL
    echo
    echo "Welcome to Texternetes, let's get started"
    echo
    echo $HL

    echo
    echo "We'll begin by creating your Dockerfile."
    echo
    echo "What kind of app are you creating?"
    echo "[1] NodeJS"
    echo "[2] Go (not available yet)"
    echo
    read -p "Enter your choice here: " appType
    echo

    if [ -z "$appType" ] || [ $appType -ne 1 ];
    then
        echo "There is an error, please try again later."
        exit 1
    fi

    echo "Which cloud are you using?"
    echo "[1] Google GKE"
    echo "[2] Azure ACS (not available yet)"
    echo
    read -p "Enter your choice here: " cloudType
    echo

    if [ -z "$cloudType" ] || [ $cloudType -lt 1 ];
    then
        echo "There is an error, please try again later."
        exit 1
    elif [ $cloudType -eq 1 ];
    then
        projects=$(gcloud projects list --format=json | jq -r '.[].projectId')
        projects=($projects)
        echo "We have found these projects in your account: "
        for proj in "${!projects[@]}";
        do  
            echo "[$(($proj+1))] ${projects[$proj]}"
        done
        echo

        echo "Which one do you want to use?"
        read -p "Enter number here: " projectName
        echo

        projectName=${projects[$(($projectName-1))]}
        echo "Using $projectName..."
        echo
        if [ -z "$projectName" ];
        then
            echo "There is an error, please try again later."
            exit 1
        fi

        echo "If you don't have any deployments yet, this may take a bit and give you a timeout error."
        echo "Just ignore it and keep going."

        deployments=$(kubectl get deployment -o json | jq -r '.items[].metadata.name')
        deployments=($deployments)
        echo
        if [ -z $deployments ];
        then
            echo "It looks like you have no deployments yet."
            read -p "What is your app name? " appName
        else
            echo "We have found these deployments in your project: "
            for dep in "${!deployments[@]}";
            do  
                echo "[$(($dep+1))] ${deployments[$dep]}"
            done
            echo "[$((${#deployments[@]}+1))] If you want to create a new deployment."
            echo
            read -p "Enter choice here: " appName
            echo
            newFlag=0
            if [[ "$appName" == "$((${#deployments[@]}+1))" ]];
            then
                newFlag=1
                read -p "Ok, what would you like to name your deployment? " appName
            else
                appName=${deployments[$(($appName-1))]}
            fi
        fi

    fi

    if [ -z "$appName" ];
    then
        echo "There is an error, please try again later."
        exit 1
    fi


    if [ "$newFlag" == 0 ];
    then
        nodes=$(kubectl get nodes -o json | jq -r '.items[].metadata.name')
        nodes=($nodes)

        numNodes=${#nodes[@]}
    else
        numNodes=0
    fi

    echo "It looks like you have $numNodes nodes in your cluster."
    read -p "Hit enter to keep it that way or enter a number to change: " numNodes

    if [ -z $numNodes ];
    then
        numNodes=${#nodes[@]}
    fi
    echo

    echo "How many pods do you want in your deployment?"
    read -p "Enter here: " numPods
    echo

    if [ -z "$numPods" ];
    then
        echo "There is an error, please try again later."
        exit 1
    fi

    echo "What version of the app is this?"
    read -p "Enter here: " appVersion
    echo

    if [ -z "$appVersion" ];
    then
        echo "There is an error, please try again later."
        exit 1
    fi

    echo $HL
    echo
    echo "Thanks, we are setting up your cluster now..."
    echo

    main "$appType" "$cloudType" "$projectName" "$appName" "$numPods" "$appVersion" "$numNodes"
elif [[ -n "$command" ]] && [[ "$command" == "help" ]];
then
    help
fi

