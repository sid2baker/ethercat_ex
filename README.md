# EthercatEx

This is a elixir wrapper for [EtherCAT](https://gitlab.com/etherlab.org/ethercat).

## Installation

'''shell
sudo ip link set <eth0> promisc on
sudo ip link set <eth0> up
sudo modprobe ec_master main_devices=<max-address>
sudo modprobe ec_generic
'''
