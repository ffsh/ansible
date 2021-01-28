##
## This Freifunk gateway was configured via Ansible
##

# Fastd status via nc & jq

Search for a key, part of the key is enough:

nc -U /run/fastd/fastd-ffsh.socket | jq . | grep -A35 132b20e02f1fc

List all connectd clients (only the address)

nc -U /run/fastd/fastd-ffsh.socket | jq '.peers[].address'

List all currently connected Peers with mac,ip and key
nc -U /run/fastd/fastd-ffsh.socket | jq -r '.peers | keys[] as $k | "\(.[$k] | .connection.mac_addresses[]?) \(.[$k] | .address) \($k)"'