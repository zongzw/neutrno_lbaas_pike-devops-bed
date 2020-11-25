import requests
import json
import sys

os_host = "10.145.73.123"
os_project_id = "e04af77e23be443989be14e22240ea75"
os_username = "admin"
os_password = "f543e5c237e54891"
listener_id = "56e0b93c-0485-4695-8614-d643bc800238"

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

def update_listener_with_tls(listener_id, name, default_tls_container_id, sni_container_refs):
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

    try:
        response = requests.request("PUT", tls_update_url, headers=headers, data = payload)
        if int(response.status_code / 200) == 1:
            print(json.dumps(json.loads(response.text.encode('utf8')), indent=2))
            return json.loads(response.text.encode('utf8'))
        else:
            print("failed to update listener: %d, %s" % (response.status_code, response.text.encode('utf-8')))
            sys.exit(1)
    except Exception as e:
        raise e

def get_bigip_profiles():
    pass


# ============================= main logic =============================

auth_token()

listener = get_listener(listener_id)
containers = get_secret_containers()

if containers['total'] < least_container_num:
    print("cannot going forwards for tests: %d containers" % containers['total'])
    sys.exit(1)

containers = {
    'A' = containers['containers'][0]['container_ref'],
    'B' = containers['containers'][1]['container_ref'],
    'C' = containers['containers'][2]['container_ref']
}
# tests: The pairs (keys and values) are composed with 'A' 'B' 'C', mean container ids as shown above
# "A B" The first letter means default_tls_container_id, the later letter(s) means sni_container_refs
# The keys are original state, the values are changed-to state.
# i.e. 
#   "A B": "C B" means: change default_tls_container_id from A to C, and keep sni_container_refs unchanged.

tests = [
    ("A", "B"),
    ("A B", "C B"),
    ("A B", "A C"),
    ("A B", "A"),
    ("A B", "A B C"),
    ("A B C", "A")
]

for (k, v) in tests:
    print(k, v)
    origins = k.split(' ')
    targets = v.split(' ')
    print(origins, targets)

    def_tls = containers[origins[0]]
    sni_tls = containers[origins[1:]]
    ls = update_listener_with_tls(listener_id, k, def_tls, sni_tls)
    get_bigip_profiles()

