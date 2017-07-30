[![Codacy Badge](https://api.codacy.com/project/badge/Grade/0c821c0fc3a54b00a408dd2fe616a724)](https://www.codacy.com/app/jacksonargo/cloudburrito?utm_source=github.com&utm_medium=referral&utm_content=jacksonargo/cloudburrito&utm_campaign=badger)
# cloudburrito [![CircleCI](https://circleci.com/gh/jacksonargo/cloudburrito.svg?style=svg)](https://circleci.com/gh/jacksonargo/cloudburrito)

A slack app to download burritos from the cloud.

### Installation:

    git clone https://github.com/jacksonargo/cloudburrito.git
    cd cloudburrito
    rvm install 2.3.3
    gem install bundler
    bundle install

### Run:

    bundle exec unicorn -c config/unicorn.rb

### Test:

    bundle exec rspec
    
### Build with docker:

    docker build . -t cloudburrito



#### Contributors
* Jackson
* Brittany
* RingZeroBot
