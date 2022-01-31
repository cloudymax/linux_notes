# why can I never remeber this

```bash

#place to save the Host private key
#the Host private key stays secret
export KEY_FILE="/Users/4008575/.ssh/BigBradley"
yes |ssh-keygen -b 2048 -f "${KEY_FILE}" -t rsa -q -N ""

# some placeholders
export LOCAL_USER="4008575"
export REMOTE_USER="max"
export REMOTE_HOST="192.168.50.64"
#copy the host's PUBLIC key into the clients

ssh-copy-id -i $KEY_FILE \
-o StrictHostKeyChecking=no \
-o ControlMaster=no \
-o ControlPath=none \
$REMOTE_USER@$REMOTE_HOST

ssh -i $KEY_FILE \
-o StrictHostKeyChecking=no \
-o ControlMaster=no \
-o ControlPath=none \
$REMOTE_USER@$REMOTE_HOST

# the long way
cat $KEY_FILE | ssh -i $REMOTE_USER@$REMOTE_HOST "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"

#push
scp -i $KEY_FILE $KEY_FILE $REMOTE_USER@$REMOTE_HOST:~/.ssh/authorized_keys

#pull
scp $REMOTE_USER@$REMOTE_HOST:/home/$REMOTE_USER/.ssh/id_rsa.pub /home/$LOCAL_USER/.ssh/authorized_keys


yes |ssh-keygen -b 2048 -f "${KEY_FILE}" -t rsa -q -N ""
touch ./cloud-init.yaml
cat $KEY_FILE.pub
ssh-keygen -R $IP_ADDRESS

```
