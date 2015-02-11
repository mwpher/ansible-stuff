#!/bin/sh
set -e
# THIS KERNEL MODULE IS NECESSARY
#   accf_http_load="YES"
# MAKE SURE JAIL HAS THE FOLLOWING OPTION IN ITS EZJAIL CONFIG FILE:
#   export jail_gitlab_parameters="allow.raw_sockets=1 allow.sysvipc=1"

ASSUME_ALWAYS_YES=YES
export ASSUME_ALWAYS_YES=YES
pkg update -f
pkg install sudo bash icu cmake pkgconf git nginx ruby ruby20-gems logrotate redis postgresql94-server postfix krb5 libxml2 libxslt

gem install bundler --no-ri --no-rdoc

sysrc sshd_enable="YES"
sysrc redis_enable="YES"
sysrc postgresql_enable="YES"
sysrc gitlab_enable="YES"
sysrc nginx_enable="YES"
sysrc postfix_enable="YES"
sysrc sendmail_enable="NO"
sysrc sendmail_submit_enable="NO"
sysrc sendmail_outbound_enable="NO"
sysrc sendmail_msp_queue_enable="NO"

# Create user
pw add user -n git -m -s /usr/local/bin/bash -c "GitLab"

# Add 'git' user to 'redis' group (this will come in useful later!)
pw user mod git -G redis

service postgresql initdb
service postgresql start

echo 'CREATE USER git CREATEDB;
CREATE DATABASE gitlabhq_production OWNER git;' > /tmp/gitlab.sql

su -l pgsql -c 'psql -d template1 -f /tmp/gitlab.sql'
rm /tmp/gitlab.sql

echo 'daemonize yes
port 0
unixsocket /usr/local/var/run/redis/redis.sock
unixsocketperm 770' > /usr/local/etc/redis.conf

# Create the directory which contains the socket
mkdir -p /usr/local/var/run/redis
chown redis:redis /usr/local/var/run/redis
chmod 755 /usr/local/var/run/redis

# Restart redis
service redis restart

# Change to git home directory
echo '#!/bin/sh
set -e
cd /home/git
git clone https://gitlab.com/gitlab-org/gitlab-ce.git -b 7-6-stable gitlab
cd /home/git/gitlab

cp config/gitlab.yml.example config/gitlab.yml
#sed "s#/home#/usr/home#g" config/gitlab.yml > config/gitlab.yml
#sed "s#/usr/bin/git#/usr/local/bin/git#g" config/gitlab.yml > config/gitlab.yml
vi config/gitlab.yml

chown -R git log/
chown -R git tmp/
chmod -R u+rwX,go-w log/
chmod -R u+rwX tmp/

mkdir /home/git/gitlab-satellites
chmod u+rwx,g=rx,o-rwx /home/git/gitlab-satellites

chmod -R u+rwX tmp/pids/
chmod -R u+rwX tmp/sockets/

chmod -R u+rwX  public/uploads

cp config/unicorn.rb.example config/unicorn.rb

vi config/unicorn.rb

cp config/initializers/rack_attack.rb.example config/initializers/rack_attack.rb

# Configure Git global settings for git user, useful when editing via web
# Edit user.email according to what is set in gitlab.yml
git config --global user.name "GitLab"
git config --global user.email "example@example.com"
git config --global core.autocrlf input

cp config/resque.yml.example config/resque.yml

# Configure Redis to use the modified socket path
# Change "production" line to "unix:/usr/local/var/run/redis/redis.sock"
vi config/resque.yml

# Copy database config
cp config/database.yml.postgresql config/database.yml

bundle config build.nokogiri --use-system-libraries

bundle install --deployment --without development test mysql aws

bundle exec rake gitlab:shell:install[v2.4.0] REDIS_URL=unix:/usr/local/var/run/redis/redis.sock RAILS_ENV=production

# Edit the gitlab-shell config
# Change the "socket" option to "/usr/local/var/run/redis/redis.sock"
# Change the "gitlab_url" option to "http://localhost:8080/"
# Don"t bother configuring any SSL stuff in here because it"s used internally
vi /home/git/gitlab-shell/config.yml' > /home/git/pt1.sh

su - git -c 'sh /home/git/pt1.sh

cd /usr/home/git/gitlab
bundle exec rake gitlab:setup RAILS_ENV=production'
# Type 'yes' to create the database tables.
# When done you see 'Administrator account created:'

#su - git -c 'bundle exec rake gitlab:setup RAILS_ENV=production GITLAB_ROOT_PASSWORD=5iveL!fe'

cp /home/git/gitlab/lib/support/init.d/gitlab /usr/local/etc/rc.d/gitlab

cd /home/git/gitlab
su - git -c 'cd /home/git/gitlab
bundle exec rake gitlab:env:info RAILS_ENV=production
bundle exec rake assets:precompile RAILS_ENV=production'

service gitlab start

echo '
worker_processes  1;
events {
    worker_connections  1024;
}
http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;
    server {  
        server_name yourserver.yourdomain;
        server_tokens off;

        listen 80 default accept_filter=httpready;

        # Uncomment if you want to use SSL
        # listen 443 ssl;

        # Configure your SSL certificate locations here
        # ssl_certificate        /usr/local/etc/nginx/ssl/gitlab/ssl-bundle.crt;
        # ssl_certificate_key  /usr/local/etc/nginx/ssl/gitlab/gitlab.key;

        # Uncomment to force SSL connections
        # if ($ssl_protocol = "") {
        #    rewrite ^   https://$server_name$request_uri? permanent;
        # }

        location / {
            proxy_set_header   X-Real-IP $remote_addr;
            proxy_set_header   Host      $http_host;
            proxy_pass         http://127.0.0.1:8080;
        }
    }
}
' > /usr/local/etc/nginx/nginx.conf

service nginx restart

su - git -c 'cd /home/git/gitlab

bundle exec rake gitlab:check RAILS_ENV=production'
