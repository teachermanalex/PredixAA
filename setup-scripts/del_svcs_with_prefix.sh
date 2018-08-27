#!/bin/bash

app_prefix=$1; shift
if [[ "${app_prefix}X" == "X" ]]; then
  echo "USAGE: $0 {prefix-regexp}, where {prefix-regexp} is the prefix your apps start with"
  echo "  eg: \"$0 dinesh\" will delete all apps and services starting with \"dinesh\""
  echo "      {prefix-regexp} can contain regular expression characters"
  exit 1
fi
if [[ "$(which cf)X" == "X" ]]; then
  echo "Please install cf"
  exit 1
fi

cf target
if [[ $? != 0 ]] ; then
   echo "cf target returned non-zero exit status.  Are you logged in with cf?"
   exit 1
fi

# Get the names of all running services that 
service_lines="$(cf services | tail -n +4 | grep "^${app_prefix}")"
no_svcs=""
if [[ "${service_lines}X" == "X" ]]; then
  echo "No services running with prefix \"$app_prefix\""
  no_svcs="True"

else

  echo "*** Matching services: ***" 
  echo "$service_lines"
fi

unbound_apps="$(cf apps | tail -n +5 | grep "^${app_prefix}" | cut -d ' ' -f 1)"
if [[ "${unbound_apps}X" == "X" && "${no_svcs}" == "True" ]] ; then
    echo "No running services or apps with prefix \"$app_prefix\" -- Exiting"
    exit 1
else

  echo "*** Matching apps: ***"
  echo "$unbound_apps"
fi

# Confirm delete
echo
echo "Will delete all of the above apps and services."
read -p "Are you sure? " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1 # handle exits from shell or function but don't exit interactive shell
fi

echo "Continuing with delete..."

# Remove all multiple spaces from service_lines

service_lines=$(echo "$service_lines" | sed -re 's,\s+, ,g')
services_to_delete=$(echo "$service_lines" | cut -d ' ' -f 1)

# Echo the services that we will work on
echo "proceeding to unbind and delete the following services:"
echo $services_to_delete 

# Loop through the services
all_apps=""
printf '%s\n' "$service_lines" | (

while IFS= read -r service_to_delete
do
    service_to_delete=$(echo "$service_to_delete" | sed -r 's/ [a-z]+ [a-z]+$//') 
    service_name=$(echo $service_to_delete | cut -d ' ' -f 1)
    bound_apps=$(echo "$service_to_delete" | cut -d ' ' -f 4- | sed 's/,//g')

    # Unbind all of the apps to each service
    for app_name in $bound_apps
    do
cf unbind-service $app_name $service_name
    done
    
    # Delete the service itself
    cf delete-service -f $service_name

    # Make a list of the apps we are going to delete
    all_apps="${all_apps} $bound_apps"
done 

# Get unique list of apps
unique_app_names=$(echo $all_apps | tr ' ' '\n' | sort | uniq)
echo "proceeding to delete the following apps:"
echo $unique_app_names

# Delete all of the apps that they were bound to
for app in $unique_app_names
do
    echo deleting app $app
    cf delete -r -f $app
done
)

# Now delete any remaining unbound apps:
unbound_apps="$(cf apps | tail -n +5 | grep "^${app_prefix}" | cut -d ' ' -f 1)"
if [[ "${unbound_apps}X" != "X" ]] ; then
  for app in $unbound_apps
  do
       cf delete -r -f $app
  done
fi
