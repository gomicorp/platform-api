#.bashrc
MY_APP_ROOT=/app

export MY_APP_ROOT

alias bash_prof="vi /root/.bashrc"
alias bash_run="source /root/.bashrc"

alias pull="git pull origin develop"
alias tt="touch $MY_APP_ROOT/tmp/restart.txt"
alias asset="cd $MY_APP_ROOT; RAILS_ENV=staging rails assets:precompile"

alias log="sudo tail -f $MY_APP_ROOT/log/staging.log"
alias console="spring stop; rails c -e staging"

alias db_drop="rake db:drop RAILS_ENV=staging DISABLE_DATABASE_ENVIRONMENT_CHECK=1"
alias create="rake db:create RAILS_ENV=staging DISABLE_DATABASE_ENVIRONMENT_CHECK=1"
alias migrate="rake db:migrate:with_data RAILS_ENV=staging DISABLE_DATABASE_ENVIRONMENT_CHECK=1"
alias dump="rake db:schema:dump RAILS_ENV=staging DISABLE_DATABASE_ENVIRONMENT_CHECK=1"
alias dbdbdb="db_drop; create; migrate"
alias credit="EDITOR=vi rails credentials:edit --environment staging"
alias safety_check="ls -al | grep .env && ls -al config | grep master.key"

alias nginx_restart="/opt/nginx/sbin/nginx -s reload"

alias gemgem="bundle install --without development test"
alias gogogo="gemgem; migrate; asset; nginx_restart; tt"
