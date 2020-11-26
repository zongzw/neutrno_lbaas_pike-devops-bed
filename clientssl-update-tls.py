import requests
import json
import sys
import base64

os_host = "10.145.73.123"
os_project_id = "e04af77e23be443989be14e22240ea75"
os_username = "admin"
os_password = "f543e5c237e54891"
listener_id = "56e0b93c-0485-4695-8614-d643bc800238"
bigip_credential = "admin:admin"
bigip_host = "10.145.68.11"

# the least container count for later tests
least_container_num = 3

authed_token = None

def auth_token():
    global authed_token

    auth_url = "http://%s:35357/v3/auth/tokens" % os_host
    payload = {
        "auth": {
            "identity": {
                "methods": [
                    "password"
                ],
                "password": {
                    "user": {
                        "name": os_username,
                        "domain": {
                            "name": "Default"
                        },
                        "password": os_password
                    }
                }
            },
            "scope": {
                "project": {
                    "id": os_project_id
                }
            }
        }
    }
    headers = {
    'Content-Type': 'application/json'
    }

    payload_data = json.dumps(payload)
    try:
        response = requests.request("POST", auth_url, headers=headers, data = payload_data)

        if int(response.status_code / 200) == 1:
            authed_token = response.headers['X-Subject-Token']
        else:
            print("failed to auth token: %d, %s" % (response.status_code, response.text.encode('utf-8')))
            sys.exit(1)
    except Exception as e:
        raise e

def get_listener(listener_id):

    listener_url = "http://%s:9696/v2.0/lbaas/listeners/%s" % (os_host, listener_id)

    payload = {}
    headers = {
    'Content-Type': 'application/json',
    'X-Auth-Token': authed_token
    }

    try:
        response = requests.request("GET", listener_url, headers=headers, data = payload)
        if int(response.status_code / 200) == 1:
            print(json.dumps(json.loads(response.text.encode('utf8')), indent=2))
            return json.loads(response.text.encode('utf8'))
        else:
            print("failed to get listeners: %d, %s" % (response.status_code, response.text.encode('utf-8')))
            sys.exit(1)
    except Exception as e:
        raise e

def get_secret_containers():
    container_url = "http://%s:9311/v1/containers" % os_host

    payload = {}
    headers = {
    'Content-Type': 'application/json',
    'X-Auth-Token': authed_token
    }

    try:
        response = requests.request("GET", container_url, headers=headers, data = payload)
        if int(response.status_code / 200) == 1:
            print(json.dumps(json.loads(response.text.encode('utf8')), indent=2))
            return json.loads(response.text.encode('utf8'))
        else:
            print("failed to get containers: %d, %s" % (response.status_code, response.text.encode('utf-8')))
            sys.exit(1)
    except Exception as e:
        raise e

def update_listener_with_tls(listener_id, default_tls_container_id, sni_container_refs, name=""):
    tls_update_url = "http://%s:9696/v2.0/lbaas/listeners/%s" % (os_host, listener_id)

    payload = {
        "listener": {
            "name": name,
            "default_tls_container_ref": default_tls_container_id,
            "sni_container_refs": sni_container_refs
        }
    }
    headers = {
        'Content-Type': 'application/json',
        'X-Auth-Token': authed_token
    }
    payload_data = json.dumps(payload)

    try:
        response = requests.request("PUT", tls_update_url, headers=headers, data = payload_data)
        if int(response.status_code / 200) == 1:
            print(json.dumps(json.loads(response.text.encode('utf8')), indent=2))
            return json.loads(response.text.encode('utf8'))
        else:
            print("failed to update listener: %d, %s" % (response.status_code, response.text.encode('utf-8')))
            sys.exit(1)
    except Exception as e:
        raise e

def get_bigip_profiles(listener_id):
    authorization = "%s" % base64.b64encode(bigip_credential)

    profiles_url = "https://%s/mgmt/tm/ltm/virtual/~Project_%s~Project_%s/profiles" % (bigip_host, os_project_id, listener_id)

    payload = {}
    headers = {
        'content-type': 'application/json',
        'Authorization': 'Basic %s' % authorization
    }

    try:
        response = requests.request("GET", profiles_url, verify=False, headers=headers, data = payload)
        
        if int(response.status_code / 200) == 1:
            print(json.dumps(json.loads(response.text.encode('utf8')), indent=2))
            return json.loads(response.text.encode('utf8'))['items']
        else:
            print("failed to update listener: %d, %s" % (response.status_code, response.text.encode('utf-8')))
            sys.exit(1)
    except Exception  as e:
        raise e

def check_listener_with_tls(listener_id, def_tls, sni_tls):
    
    listener = get_listener(listener_id)
    if listener['listener']['default_tls_container_ref'] != def_tls:
        raise Exception("listener default_tls_container_ref doesn't match!")
    
    if sorted(listener['listener']['sni_container_refs']) !=  sorted(sni_tls):
        raise  Exception("listener sni_container_refs doesn't match!")

    profiles = get_bigip_profiles(listener_id)

    def is_ssl_profile(n):
        return n['context'] == 'clientside'
    ssl_profiles = filter(is_ssl_profile, profiles)
    
    if len([def_tls] +sni_tls) != len(ssl_profiles):
        raise Exception("The length of ssl profiles doesn't match.")

    def id_found(id):
        for n in profiles:
            if n['fullPath'].find(id) != -1:
                return True
        return False

    def_tls_id = def_tls.split('/')[-1]
    if not id_found(def_tls_id):
        raise  Exception("default tls id  %s cannot be found in profiles: %s"  % (def_tls_id,  profiles))
    
    for n in sni_tls:
        sni_tls_id  =n.split('/')[-1]
        if not id_found(sni_tls_id):
            raise Exception("sni  tls  id  %s cannot  be  found  in profiles: %s"%(sni_tls_id, profiles))
    



# ============================= main logic =============================

auth_token()

containers = get_secret_containers()

if containers['total'] < least_container_num:
    print("cannot going forwards for tests: %d containers" % containers['total'])
    sys.exit(1)

containers = {
    'A': containers['containers'][0]['container_ref'],
    'B': containers['containers'][1]['container_ref'],
    'C': containers['containers'][2]['container_ref']
}
# tests: 'A' 'B' 'C', mean container ids as shown above
# "A B" The first letter means default_tls_container_id, the later letter(s) means sni_container_refs
# In tests array, listeners' tls setting transitions from tests[0] to tests[1],  to ... tests[n]
# i.e. 
#   ..., "A B", "C B", ... means: change default_tls_container_id from A to C, and keep sni_container_refs unchanged.

tests = [
    "A", "B", "A", "A B", "C B", "A B", "A C", "A B", "A B C", "A B", "C"
]

tls = tests[0].split(' ')
def_tls = containers[tls[0]]
sni_tls = [containers[n] for n in tls[1:]]
ls = update_listener_with_tls(listener_id, def_tls, sni_tls, name=tests[0])
check_listener_with_tls(listener_id, def_tls, sni_tls)

for t in tests[1:]:
    print(t)
    tls = t.split(' ')
    def_tls = containers[tls[0]]
    sni_tls = [containers[n] for n in tls[1:]]
    ls = update_listener_with_tls(listener_id, def_tls, sni_tls, name=t)
    check_listener_with_tls(listener_id, def_tls, sni_tls)

