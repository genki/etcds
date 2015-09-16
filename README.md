# Etcds

A etcd cluster manager.

## Installation

etcd depends on etcd-ca, so you should install it in advance like this:

```
go get github.com/coreos/etcd-ca
```

After that, add this line to your application's Gemfile:

```ruby
gem 'etcds'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install etcds

## Usage

Before run etcds command, you should prepare the configuration file
`etcds.yml` at current directory.

% etcds [sub command] [options] [args]

```
Available sub commands:
  ctl      [name] commands      pass commands to etcdctl
  health   show cluster health for all nodes
  init     prepare ca files for all nodes
  install  [names...]   install ca files to the host
  ls       list up nodes
  member   show member list for all nodes
  ps       list up etcd containers
  rm       [names...]   remove stopped nodes
  stop     [names...]   stop nodes
  up       [names...]   prepare and activate etcd
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake false` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/etcds. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

