# ansible
This repository holds the ansible playbook to deploy a ffsh gateway in the standard configuration.
It is based on https://docs.freifunk-suedholstein.de/de/latest/gateway.html but changes where made where it was plausable.

# requirements

## ssh-key
As the login is done via ssh make sure that the ssh key is registered at your identity manager `ssh-add $keyfile`.
That way ansible will be able to automatically detect the right ssh key and connect to the server.

## hosts
If you want to deploy to a new gateway you need to add it to the hosts file.

## host_vars/$gatewayname.yml
You need to supply your fastd secret as an encrpyted password, you may use the standard password or your own. #TODO check

To create a new fastd secret, execute the following, this will ask you for a password and open a editor.
```
ansible-vault create --vault-id fastd_key@prompt host_vars/brunsbach.yml
```
Enter
```
fastd_secret: $yourkey
```
save and close the editor, done you added your secret :)

You can change the content any time by
```
ansible-vault edit --vault-id fastd_key@prompt host_vars/brunsbach.yml
```