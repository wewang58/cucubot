require 'cinch'
require 'json'
require 'open-uri'
require 'tzinfo'
require 'tzinfo/data'

#Borrowed heavily from https://raw.githubusercontent.com/cinchrb/cinch/master/examples/plugins/timer.rb
class LaggardPlugin
  include Cinch::Plugin
  #Every 2 hours (7200 seconds) run the 'check_scrums' method
  timer 7200, method: :check_scrums
  def check_scrums

    #Get a list of channel users to compare against the db of usernames
    user_list = []
    channel = Channel("#{ENV['CUCUSHIFT_IRC_CHANNEL']}")
    channel.users.each do |user|
      user_list << user[0].nick
    end

    #Check the scrum5000 app for users who have and have not filled out a scrum
    #If response is empty, everyone filled out a scrum, otherwise, send a private
    #message to the person.
    response = open("#{ENV['CUCUBOT_SCRUM5000']}/bot_portal/bot_checkpoint.json").read
    if response.empty?
      #Uncomment the following line to spam the channel with an all-clear message
      #Channel(ENV['CUCUSHIFT_IRC_CHANNEL']).send "No laggards today!"
      puts "No laggards today!"
    else
      parsed = JSON.parse(response)
      parsed.each do |unreported|
        #Determine the user's timezone, if no tz can be found, send anyway
        #TODO: Find out how to test for bad TZ info, like just "Perth" instead of "Australia/Perth"
        #unreported[1][1] is the timezone data, unreported[1][0] is the irc username, as found in the
        #parsed JSON file.
        user_timezone = unreported[1][1]
        user_irc_nick = unreported[1][0]
        if user_timezone
          #Get timezone info
          current_tz_info = TZInfo::Timezone.get("#{user_timezone}").now
          day_num = current_tz_info.wday
          hour_num = current_tz_info.hour

          #Uncomment the below line to spam the channel with users
          #who have not yet filled out a scrum
          #Channel(ENV['CUCUSHIFT_IRC_CHANNEL']).send "#{unreported[1]}"

          if day_num >=1 and day_num<=5 and hour_num >=8 and hour_num <=18
            #Add support for regex when user changes name

            #TODO: do User.find on the irc nick, if not found, do the following.
            real_user_nick_list = find_regex_user("#{user_irc_nick}", user_list)
            real_user_nick_list.each do |real_user_nick|
              User("#{real_user_nick}").send("#{user_irc_nick}, please fill out your scrum today. #{ENV['CUCUBOT_SCRUM5000']}")
            end
          end
        else
          #TODO: do something with those that don't have a correct tz
          puts "Placeholder"
        end
      end
    end
  end
  def find_regex_user(user_irc_nick, user_list)
    #Search for the db username (or similar name)  in the current channel list.
    #If the username is not in the channel list, return the name
    #else, return the name that matches closest (i.e. if user renamed their nick)
    nick_list = []
    similar_names = user_list.grep /#{user_irc_nick}/
    if similar_names.empty?
      nick_list << user_irc_nick
    else
      nick_list = similar_names
    end
  end
end
