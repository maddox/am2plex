require 'itunes_parser'
require 'json'
require 'yaml'

require './lib/db.rb'
require './lib/models.rb'

config = YAML.load_file("./config/config.yml")
is_dry_run = ARGV[0] == '--dry-run'
default_date = DateTime.parse(config["default_date"])

if !is_dry_run
  # prompt to continue
  puts "This will update the Plex database. Are you sure you want to continue? (y/n)"
  response = gets.chomp
  if response != "y"
    puts "Exiting..."
    exit 0
  end
else
  puts "Here is some information about your Plex server"
  puts "Found Account IDs: #{PlexMetadataItemView.distinct.pluck(:account_id).compact.join(", ")}"
  puts "Found Devices IDs: #{PlexMetadataItemView.distinct.pluck(:device_id).compact.join(", ")}\n\n"
end

puts "Reading Apple Music tracks...\n\n"

parser = ItunesParser.new(file: "./config/apple-music.xml")
start_time = Time.now

apple_music_tracks = parser.tracks.values

artists_not_found = []
albums_not_found = []
tracks_not_found = []
tracks_found = []

filtered_tracks = []
tracks_to_match = []
compilation_tracks_to_match = []

start_time = Time.now

# Remove tracks that have not been played or skipped
puts "# of tracks from Apple Music: #{apple_music_tracks.size}\n\n"
puts "Filtering tracks based on these preferences...\n\n"
puts "Minimum plays: #{config["minimum_plays"]}"
puts "Minimum skips: #{config["minimum_skips"]}\n\n"
apple_music_tracks.each do |track|
  if !track["Play Count"].nil? && track["Play Count"] >= config["minimum_plays"] 
    filtered_tracks << track
    next
  end

  if !track["Skip Count"].nil? && track["Skip Count"] >= config["minimum_skips"] 
    filtered_tracks << track
    next
  end
end

# Break up tracks based on if they are from a compilation
puts "Splitting up compilation tracks...\n\n"
filtered_tracks.each do |track|
  if track["Compilation"]
    compilation_tracks_to_match << track 
  else
    tracks_to_match << track
  end
end

puts "# of normal tracks to sync: #{tracks_to_match.size}"
puts "# of compilation tracks to sync: #{compilation_tracks_to_match.size}\n\n"

puts "Comparing tracks...\n\n"

tracks_to_match.each do |apple_music_track|
  artist_name = apple_music_track["Album Artist"] || apple_music_track["Artist"]
  album_name = apple_music_track["Album"]
  track_name = apple_music_track["Name"]
  track_number = apple_music_track["Track Number"]
  disc_number = apple_music_track["Disc Number"]

  next if artist_name.nil? || album_name.nil? || track_name.nil?
  next if artist_name == "" || album_name == "" || track_name == ""
  next if artists_not_found.include?(artist_name)
  
  artist = PlexArtist.find_by_name(artist_name)
  if artist.nil?
    artists_not_found << artist_name
    next
  end

  next if albums_not_found.map{|a| a[:album_name]}.include?(album_name)
  album = artist.albums.find_by_name(album_name)
  if album.nil?
    albums_not_found << {artist_name: artist_name, album_name: album_name}
    next
  end

  track = album.tracks.find_by_name(track_name)

  # try to match track by track number
  if track.nil? && track_number
    track = album.tracks.find_by(index: track_number)
    if !track.nil? && is_dry_run
      puts "found track by track number" 
      puts "source: #{track_name} - #{track_number} - #{album_name}- #{artist_name}"
      puts "found:  #{track.title} - #{track.index}\n\n"
    end
  end

  if track.nil?
    tracks_not_found << {artist_name: artist_name, album_name: album_name, track_name: track_name}
    next
  else
    tracks_found << apple_music_track
  end
end

puts "Artists not found: #{artists_not_found.size}"
if is_dry_run
  puts "Writing missing artists to missing_artists.json...\n\n"
  File.open("./missing_artists.json", "w") do |f|
    artist_hash = artists_not_found.inject({}) { |hash, artist| hash[artist] = artist; hash }
    f.write(JSON.pretty_generate(artist_hash))
  end
  puts artists_not_found
  puts
end

puts "Albums not found: #{albums_not_found.size}"
if is_dry_run
  puts "Writing missing albums to missing_albums.json...\n\n"
  File.open("./missing_albums.json", "w") do |f|
    album_hash = albums_not_found.inject({}) { |hash, album| hash[album[:album_name]] = album[:album_name]; hash }
    f.write(JSON.pretty_generate(album_hash))
  end
  puts albums_not_found.map{|a| "#{a[:artist_name]} - #{a[:album_name]}"}
  puts
end

puts "Tracks not found: #{tracks_not_found.size}"
if is_dry_run
  puts "Writing missing tracks to missing_tracks.json...\n\n"
  File.open("./missing_tracks.json", "w") do |f|
    track_hash = tracks_not_found.inject({}) { |hash, track| hash[track[:track_name]] = track[:track_name]; hash }
    f.write(JSON.pretty_generate(track_hash))
  end
  puts tracks_not_found.map{|t| "#{t[:artist_name]} - #{t[:album_name]} - #{t[:track_name]}"}
  puts
end

puts "Tracks found: #{tracks_found.size} out of #{tracks_to_match.size}"
puts
puts "Time: #{Time.now - start_time} seconds"

if !is_dry_run
  tracks_found.each do |apple_music_track|
    artist_name = apple_music_track["Album Artist"] || apple_music_track["Artist"]
    album_name = apple_music_track["Album"]
    track_name = apple_music_track["Name"]
    track_number = apple_music_track["Track Number"]
    play_count = apple_music_track["Play Count"]
    last_played_date = apple_music_track["Play Date UTC"] || apple_music_track["Date Modified"] || default_date
    skip_count = apple_music_track["Skip Count"]
    last_skipped_date = apple_music_track["Skip Date"] || apple_music_track["Date Modified"] || default_date
    track_rating = apple_music_track["Rating"]/10 if apple_music_track["Rating"]
    album_rating = apple_music_track["Album Rating"]/10 if apple_music_track["Album Rating"]
    loved = apple_music_track["Loved"]

    artist = PlexArtist.find_by_name(artist_name)
    album = artist.albums.find_by_name(album_name)
    track = album.tracks.find_by_name(track_name)
    track = album.tracks.find_by(index: track_number) if track.nil? && track_number

    next unless track

    puts "Importing details of #{apple_music_track["Artist"]} - #{apple_music_track["Album"]} - #{apple_music_track["Name"]}"

    if config["import_plays"]
      puts "Importing plays to plex database..."
      puts "Play Count: #{play_count}"
      puts "Last Played: #{last_played_date}\n\n"
      if play_count && play_count > 0
        for i in 1..play_count
          track.add_listen_at(last_played_date, config['account_id'], config['device_id'])
        end
      end
    end

    if config["import_skips"]
      puts "Importing skips to plex database..."
      puts "Skip Count: #{skip_count}"
      puts "Last Skipped: #{last_skipped_date}\n\n"

      if skip_count && skip_count > 0
        for i in 1..skip_count
          track.add_listen_at(last_skipped_date, config['account_id'], config['device_id'])
        end
      end
    end

    if config["import_track_ratings"] && track_rating
      the_rating = track_rating || track_loved ? 10 : 0
      puts "Importing track rating to plex database..."
      puts "Track Rating: #{the_rating}\n\n"
      track.set_rating(the_rating, config['account_id'])
    end

    if config["import_album_ratings"] && album_rating
      puts "Importing album rating to plex database..."
      puts "Album Rating: #{album_rating}\n\n"
      track.album.set_rating(album_rating, config['account_id'])
    end

  end
end