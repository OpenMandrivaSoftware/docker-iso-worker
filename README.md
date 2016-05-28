# How to launch

REDIS_HOST=172.17.0.1 REDIS_PORT=6379 REDIS_PASSWORD=redis BUILD_TOKEN=<abf_token> sidekiq -q iso_worker -c 1 -r ./lib/abf-worker.rb
