#!/bin/sh

# TODO: Need to handle in a gem friendly way.

unicorn -c unicorn.conf config.ru $1

