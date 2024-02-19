# frozen_string_literal: true

desc 'Lint files'

task lint: :environment do
  puts 'Beautifying files'
  Rake::Task['lint:eslint'].invoke
  Rake::Task['lint:csslint'].invoke
  Rake::Task['lint:rubocop'].invoke
  Rake::Task['lint:erblint'].invoke
  puts 'Beautified files'
end

namespace :lint do
  desc 'Beautifying ruby files'
  task rubocop: :environment do
    puts "\nRunning rubocop\n"
    system('rubocop -a')
  end

  desc 'Beautifying erb files'
  task erblint: :environment do
    puts "\nRunning erblint\n"
    system('erblint --lint-all --autocorrect')
  end

  desc 'Beautifying javascript files'
  task eslint: :environment do
    puts "\nRunning eslint\n"
    `yarn lint:fix`
  end

  desc 'Beautifying css files'
  task csslint: :environment do
    puts "\nRunning csslint\n"
    `yarn csslint:fix`
  end
end
