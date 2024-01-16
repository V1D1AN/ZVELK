#!/bin/bash
SCRIPTDIR="$(pwd)"
mkdir certs
cp env.sample .env
echo "##########################################"
echo "###### CONFIGURING ACCOUNT ELASTIC #######"
echo "###### AND KIBANA API KEY          ######"
echo "##########################################"
echo  
echo
password=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c14)
kibana_password=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c14)
kibana_api_key=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c32)
mysql_password=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c32)
echo "The master password Elastic set in .env:" $password
echo "The master password Kibana set in .env:" $kibana_password
echo "The Kibana api key is : " $kibana_api_key
sed -i "s|kibana_api_key|$kibana_api_key|g" kibana/kibana.yml
sed -i "s|kibana_changeme|$kibana_password|g" .env
echo
echo
echo "##########################################"
echo "####### CONFIGURING ADMIN ACCOUNT ########"
echo "####### FOR KIBANA / VELOCIRAPTOR ########"
echo "##########################################"
echo
echo
read -r -p "Enter the admin account (Must be like user@domain.tld):" admin_account
admin_account=$admin_account
sed -i "s|zircolite_account|$admin_account|g" .env
echo
while true; do
    read -s -p "Password (Must be a password with at least 6 characters):" admin_password
    echo
    read -s -p "Password (again):" admin_password2
    echo
    [ "$admin_password" = "$admin_password2" ] && break
    echo "Please try again"
done
sed -i "s|zircolite_password|$admin_password|g" .env
echo
echo
echo "##########################################"
echo "####### CONFIGURING HOSTNAME S1EM ########"
echo "##########################################"
echo
echo
read -r -p "Enter the hostname or IP of the solution S1EM (ex: s1em.cyber.local or 192.168.0.1):" s1em_hostname
s1em_hostname=$s1em_hostname
sed -i "s|s1em_hostname|$s1em_hostname|g" docker-compose.yml homer/config.yml .env
echo
echo
echo "##########################################"
echo "### CONFIGURING CLUSTER ELASTICSEARCH  ###"
echo "##########################################"
echo
echo
read -p "Enter the RAM in Go of node elasticsearch [2]:" master_node
master_node=${master_node:-2}
sed -i "s|RAM_MASTER|$master_node|g" docker-compose.yml
sed -i "s|changeme|$password|g" .env kibana/kibana.yml logstash/config/logstash.yml logstash/pipeline/zircolite/300_output_zircolite.conf logstash/pipeline/velociraptor/300_output_velociraptor.conf
echo
echo
echo "##########################################"
echo "######### CONFIGURING INTERFACES #########"
echo "##########################################"
echo
echo
ip a | egrep -A 2 "ens[[:digit:]]{1,3}:|eth[[:digit:]]{1,3}:"
echo
echo
read -r -p "Enter the administration interface (ex:ens32):" administration_interface
administration_interface=$administration_interface
INTERFACE=`netstat -rn | grep ${administration_interface} | awk '{ print $NF }'| tail -n1`
ADMINISTRATION_IP=`ifconfig ${INTERFACE} | grep inet | awk '{ print $2 }' | grep -o -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'`
echo "Interface: ${INTERFACE}   IP found: ${ADMINISTRATION_IP}"
sed -i "s;administrationip;${ADMINISTRATION_IP};" instances.yml .env
echo
echo
echo "##########################################"
echo "############# CONFIRMATION ###############"
echo "##########################################"
echo
echo
echo "The administration account: $admin_account"
echo "The S1EM hostname: $s1em_hostname"
echo "The cluster Elasticsearch: $cluster"
echo "The RAM of Master node of Elasticsearch: $master_node"
echo "The administration interface: $administration_interface"
echo "The administration ip: $ADMINISTRATION_IP"
echo
while true; do
    read -r -p "Do you confirm for installation [Y/N]?" choice
    case $choice in
        [Yy]) echo "Starting of installation"; break;;
        [Nn]) echo "Stopping of installation"; exit 0;;
        * ) echo "Please answer (Y/y) or (Y/y).";;
    esac
done
echo
echo
echo "##########################################"
echo "######### GENERATE CERTIFICATE ###########"
echo "##########################################"
echo
echo
docker compose run --rm certificates
echo
echo
echo "##########################################"
echo "########## DOCKER DOWNLOADING ############"
echo "##########################################"
echo
echo
docker compose pull
echo
echo
echo "##########################################"
echo "########## STARTING TRAEFIK ##############"
echo "##########################################"
echo
echo
docker compose up -d traefik
echo
echo
echo "##########################################"
echo "############# STARTING HOMER #############"
echo "##########################################"
echo
echo
docker compose up -d homer
echo
echo
echo "##########################################"
echo "##### STARTING ELASTICSEARCH/KIBANA ######"
echo "##########################################"
echo
echo
docker compose up -d es01 kibana
while [ "$(docker exec es01 sh -c 'curl -sk https://127.0.0.1:9200 -u elastic:$password')" == "" ]; do
  echo "Waiting for Elasticsearch to come online.";
  sleep 15;
done
echo
echo
echo "##########################################"
echo "########## DEPLOY KIBANA INDEX ###########"
echo "##########################################"
echo
echo
while [ "$(docker logs kibana | grep -i "server running" | grep -v "NotReady")" == "" ]; do
  echo "Waiting for Kibana to come online.";
  sleep 15;
done
echo "Kibana is online"
docker exec es01 sh -c "curl -sk -X POST 'https://127.0.0.1:9200/_security/user/kibana_system/_password' -u 'elastic:$password' -H 'Content-Type: application/json'  -d '{\"password\":\"$kibana_password\"}'" >/dev/null 2>&1
docker exec es01 sh -c "curl -sk -X POST 'https://127.0.0.1:9200/_security/user/$admin_account' -u 'elastic:$password' -H 'Content-Type: application/json' -d '{\"enabled\": true,\"password\": \"$admin_password\",\"roles\":\"superuser\",\"full_name\": \"$admin_account\"}'" >/dev/null 2>&1
for index in $(find kibana/index/* -type f); do docker exec kibana sh -c "curl -sk -X POST 'https://kibana:5601/kibana/api/saved_objects/_import?overwrite=true' -u 'elastic:$password' -H 'kbn-xsrf: true' -H 'Content-Type: multipart/form-data' --form file=@/usr/share/$index >/dev/null 2>&1"; done
sleep 10
for dashboard in $(find kibana/dashboard/* -type f); do docker exec kibana sh -c "curl -sk -X POST 'https://kibana:5601/kibana/api/saved_objects/_import?overwrite=true' -u 'elastic:$password' -H 'kbn-xsrf: true' -H 'Content-Type: multipart/form-data' --form file=@/usr/share/$dashboard >/dev/null 2>&1"; done
sleep 10
echo
echo
echo "##########################################"
echo "########## STARTING LOGSTASH #############"
echo "##########################################"
echo
echo
docker compose up -d logstash
echo
echo
echo "##########################################"
echo "######### STARTING VELOCIRAPTOR ##########"
echo "##########################################"
echo
echo
docker compose up -d velociraptor
echo "Waiting for the start of velociraptor."
sleep 30
docker exec -ti velociraptor bash -c "/velociraptor/velociraptor config generate > /velociraptor/server.config.yaml --merge '{\"gui\":{\"use_plain_http\":true,\"base_path\":\"/velociraptor\",\"public_url\":\"https://$s1em_hostname/velociraptor\",\"bind_address\":\"0.0.0.0\"}}'" 2>&1
docker exec -ti velociraptor bash -c "/velociraptor/velociraptor --config /velociraptor/server.config.yaml user add $admin_account $admin_password --role administrator" 2>&1
docker restart velociraptor
echo 
echo
echo "#########################################"
echo "###### CONFIGURATION DE REPLAY ##########"
echo "#########################################"
echo
echo
chmod 755 replay/replay.sh
instance=$(grep -oP 'INSTANCE=\K.*' .env)
sed -i "s|instance_name|$instance|g" replay/replay.sh
echo
echo
echo "##########################################"
echo "########## STARTING DATABASES ############"
echo "##########################################"
echo
echo
docker compose up -d db
echo
echo
echo "#########################################"
echo "####### STARTING OTHER DOCKER ###########"
echo "#########################################"
echo
echo
docker compose up -d cyberchef zircolite-upload velociraptor-upload replay spiderfoot codimd 
echo
echo
echo "#########################################"
echo "############ DEPLOY FINISH ##############"
echo "#########################################"
echo
echo "Access url: https://$s1em_hostname"
echo "Use the user account $admin_account for access to Kibana / Velociraptor"
echo "The master password of elastic is in \".env\" "
