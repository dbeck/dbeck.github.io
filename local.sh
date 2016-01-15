#!/bin/sh
git pull
cp Gemfile.local Gemfile
bundle install
bundle exec jekyll serve
