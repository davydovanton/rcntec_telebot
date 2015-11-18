require 'telegram/bot'
require 'sequel'
DB = Sequel.connect("sqlite://telegram_swearing.db")
TOKEN = ''

DB.create_table :users do
  primary_key :id
  String :name
  foreign_key :offence_id, :offences
end

DB.create_table :offences do
  primary_key :id
  String :word
  String :message
  foreign_key :user_id, :users
end

DB.create_table :swearings do
  primary_key :id
  String :word
end

class User < Sequel::Model
  one_to_many :offences
end

class Offence < Sequel::Model
  many_to_one :user
end

class Swearing < Sequel::Model
  def self.all_words
    self.all.map(&:word)
  end
end

Telegram::Bot::Client.run(TOKEN) do |bot|
  bot.listen do |message|
    if Swearing.all_words.any?{ |w| message.text =~ /#{w}/ }
      full_name = "#{message.from.first_name} #{message.from.last_name}"
      user = User.find_or_create name: full_name
      Offence.create word: $~, message: message.text, user_id: user.id
      bot.api.send_message(chat_id: message.chat.id, text: "#{full_name} says #{$~}")
    end

    case message.text
    when '/status'
      users_status = User.all.map{|u| "#{u.name} - #{u.offences.count} offences" }.join("\n")
      bot.api.send_message(chat_id: message.chat.id, text: "Current status:\n#{users_status}")
    when /\/status/
      user = User[name: message.text.sub(/\/status /, '')]
      user_status = user.offences.group_by(&:word)
        .map{ |(word, offences)| "  #{word} - #{offences.count}" }.join("\n")
      bot.api.send_message(chat_id: message.chat.id, text: "Status for #{user.name}:\n#{user_status}")
    when /\/add/
      swearing = Swearing.find_or_create word: message.text.split.last
      bot.api.send_message(chat_id: message.chat.id, text: "Create new swearing - '#{swearing.word}'")
    end
  end
end
