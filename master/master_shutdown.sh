#!/bin/bash
sudo kubectl delete sts --all
sudo kubectl delete pod --all
sudo kubectl delete pvc --all
sudo kubectl delete pv --all
sudo kubectl delete service --all
sudo systemctl stop kubelet
sudo kubeadm reset
sudo systemctl stop docker
rm -rf ../nfs_share/*
