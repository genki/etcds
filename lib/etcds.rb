require "etcds/version"
require "yaml"
require "colorize"
require "net/https"
require "openssl"

class Etcds
  LABEL_BASE = 'com.s21g.etcds'
  H = {}

  def initialize
    config = './etcds.yml'
    case ARGV.first
    when '-f'; _, config = ARGV.slice! 0, 2
    when '-v'; puts "etcds version #{VERSION}"; exit
    when '-h', nil
      system "#{$0} -v"
      system "etcd-ca -v"
      puts "config: #{config}"
      ms = (public_methods.sort - Object.methods)
      mlen = ms.map(&:length).max
      puts "Available sub commands:"
      ms.each{|m| puts "  %-#{mlen+2}s#{H[m.intern]}" % m}
      exit
    end
    @nodes = YAML.load_file config
  end

  H[:ls] = 'list up nodes'
  def ls
    @nodes.each do |k,v|
      ip = v['ip']
      state = case
      when run?(k); 'running'
      when exist?(k); 'stopped'
      else 'not exist'
      end
      puts "#{k}: ip=#{ip} #{state}"
    end
  end

  H[:init] = 'prepare ca files for all nodes'
  def init(domain = 'etcd')
    etcd_ca "init --passphrase ''"
    @nodes.each do |k, v|
      ip = v['ip']
      name = k
      etcd_ca "new-cert --passphrase '' --ip #{ip} --domain #{domain} #{name}"
      etcd_ca "sign --passphrase '' #{name}"
      etcd_ca "export --insecure --passphrase '' #{name}" +
        " | tar -C ./certs -xvf -"
      etcd_ca "chain #{name} > ./certs/#{name}.ca.crt"
    end
    etcd_ca "new-cert --passphrase '' client"
    etcd_ca "sign --passphrase '' client"
    etcd_ca "export --insecure --passphrase '' client | tar -C ./certs -xvf -"
    unless File.exist?(discovery_path)
      system "curl https://discovery.etcd.io/new > #{discovery_path}"
    end
  end

  H[:install] = "[names...]\tinstall ca files to the host"
  def install(*hosts)
    hosts.each do |to|
      %W[
        #{to}.ca.crt #{to}.crt #{to}.key.insecure
        ca.crt client.crt client.key.insecure
      ].each do |what|
        scp "./certs/#{what} #{to}:/tmp/"
        ssh to, "mv /tmp/#{what} /etc/docker/certs.d"
        ssh to, "chown root:root /etc/docker/certs.d/#{what}"
      end
    end
  end

  H[:ps] = 'list up etcd containers'
  def ps(*args)
    @nodes.keys.each do |n|
      puts "Node #{n}:".on_blue
      puts docker(n, "ps -f label=#{LABEL_BASE}.name #{args*' '}") + "\n"
    end
  end

  H[:stop] = "[names...]\tstop nodes"
  def stop(*names)
    names = @nodes.keys if names.empty?
    names.each do |n|
      cid = docker n, "ps -qf label=#{LABEL_BASE}.name=#{n}"
      if cid.empty?
        STDERR.puts "etcd is not running at #{n}"
        next
      end
      docker n, "stop #{cid}"
      puts "etcd is stopped at #{n}"
    end
  end

  H[:rm] = "[names...]\tremove stopped nodes"
  def rm(*names)
    names.each do |n|
      cid = docker n, "ps -q -f status=exited -f label=#{LABEL_BASE}.name=#{n}"
      if cid.empty?
        STDERR.puts "etcd is not stopped or existing at #{n}"
        next
      end
      docker n, "rm #{cid}"
      puts "etcd is removed at #{n}"
    end
  end

  H[:up] = "name\tprepare and activate etcd"
  def up(n, *args)
    node = @nodes[n]
    ip = node['ip']
    stop n if run? n
    rm n if exist? n
    docker n, "run -d -p 2379:2379 -p 2380:2380 --name etcd" +
      " -e ETCD_TRUSTED_CA_FILE=/certs/#{n}.ca.crt" +
      " -e ETCD_CERT_FILE=/certs/#{n}.crt" +
      " -e ETCD_KEY_FILE=/certs/#{n}.key.insecure" +
      " -e ETCD_CLIENT_CERT_AUTH=1" +
      " -e ETCD_PEER_TRUSTED_CA_FILE=/certs/#{n}.ca.crt" +
      " -e ETCD_PEER_CERT_FILE=/certs/#{n}.crt" +
      " -e ETCD_PEER_KEY_FILE=/certs/#{n}.key.insecure" +
      " -e ETCD_PEER_CLIENT_CERT_AUTH=1" +
      " -e ETCD_HEARTBEAT_INTERVAL=100" +
      " -e ETCD_ELECTION_TIMEOUT=2500" +
      " -v /var/lib/etcd" +
      " -v /etc/docker/certs.d:/certs" +
      " -v /etc/ssl/certs:/etc/ssl/certs" +
      " -l #{LABEL_BASE}.name=#{n}" +
      " quay.io/coreos/etcd" +
      " -name #{n} -data-dir /var/lib/etcd/#{n}.etcd" +
      " -listen-client-urls https://0.0.0.0:2379" +
      " -listen-peer-urls https://0.0.0.0:2380" +
      " -advertise-client-urls https://#{ip}:2379" +
      " -initial-advertise-peer-urls https://#{ip}:2380" +
      " -discovery #{discovery} " + args*' '
    puts "etcd is started at #{n}"
  end

  H[:health] = 'show cluster health for all nodes'
  def health; for_all{|n| ctl n, 'cluster-health'} end

  H[:member] = 'show member list for all nodes'
  def member; for_all{|n| ctl n, 'member list'} end

  H[:ctl] = "[name] commands\tpass commands to etcdctl"
  def ctl(n, *args)
    node = @nodes[n]
    ip = node['ip']
    system "etcdctl -C https://#{ip}:2379" +
      " --cert-file ./certs/client.crt" +
      " --key-file ./certs/client.key.insecure" +
      " --ca-file ./certs/#{n}.ca.crt " + args*' '
  end

  H[:get] = "name:/path\tGET via ssl"
  def get(query)
    n, path = query.split(':', 2)
    node = @nodes[n]
    ip = node['ip']
    puts https(ip, 2379).get(path).body
  end

  def discover
    system "curl #{discovery}"
  end

private
  def load_cert(path) OpenSSL::X509::Certificate.new open(path).read end
  def load_key(path) OpenSSL::PKey.read open(path).read end
  def discovery_path; './certs/discovery' end
  def discovery; open(discovery_path).read.chomp end
  def etcd_ca(cmd) system "etcd-ca --depot-path ./certs #{cmd}" end
  def dm(cmd) system "docker-machine #{cmd}" end
  def scp(cmd) dm "scp #{cmd}" end
  def ssh(name, cmd) dm "ssh #{name} \"sudo -u root #{escape cmd}\"" end
  def escape(cmd) cmd.gsub /"/, '\"' end
  def run?(n) !docker(n, "ps -qf label=#{LABEL_BASE}.name=#{n}").empty? end
  def exist?(n) !docker(n, "ps -qaf label=#{LABEL_BASE}.name=#{n}").empty? end

  def docker(name, cmd)
    ip = @nodes[name]['ip']
    IO.popen({'DOCKER_HOST' => "tcp://#{ip}:2376"}, "docker #{cmd}").read
  end

  def for_all(&block)
    @nodes.keys.each do |n|
      if run?(n)
        puts "Node #{n}:".on_blue
        block[n]
      else
        puts "Node #{n}: not running".on_yellow
      end
    end
  end

  def https(ip, port)
    Net::HTTP.new(ip, port).tap do |c|
      c.use_ssl = true
      c.ca_file = "./certs/ca.crt"
      c.cert = load_cert "./certs/client.crt"
      c.key = load_key "./certs/client.key.insecure"
      c.verify_mode = OpenSSL::SSL::VERIFY_PEER
    end
  end
end
