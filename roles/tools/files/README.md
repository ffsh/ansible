##
## This Freifunk gateway was configured via Ansible
##

# Check Batman Status

batctl -v

## Fix broken batman-adv module

Execute "fix-batman.sh" in /root.

# Fastd

## Stop fastd service to prevent clients from connecting

systemctl stop fastd@ffsh.service

## start

systemctl stop fastd@ffsh.service

# Wireguard

Check status with command: wg

Check connection via interface with curl

curl --interface exit https://www.google.com

If you get lot's of js, html and css it worked.

## Regenerate config

wg-conf-gen recreate

## stop

systemctl stop wg-quick@exit.service

## start

systemctl startp wg-quick@exit.service

# Fastd status via nc & jq

Search for a key, part of the key is enough:

nc -U /run/fastd/fastd-ffsh.socket | jq . | grep -A35 132b20e02f1fc

List all connectd clients (only the address)

nc -U /run/fastd/fastd-ffsh.socket | jq '.peers[].address'

List all currently connected Peers with mac,ip and key
nc -U /run/fastd/fastd-ffsh.socket | jq -r '.peers | keys[] as $k | "\(.[$k] | .connection.mac_addresses[]?) \(.[$k] | .address) \($k)"'