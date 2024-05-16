# Apple Music -> Plex !!

This tool will help you import data from your Apple Music library into Plex to help you get going with Plexamp and off horrible streaming music services.

It will import:

- track play counts
- last played date
- track skip counts
- last skiped date
- album ratings
- track ratings

You have the ability to tweak which tracks are skippd by setting the minimum play count and skip count on tracks to import.

This tool is not perfect. It errs on the side of avoiding false positives. So while it might not import everything, it should at least not make mistakes when matching tracks with your Plex library.

## tl;dr on how it works.

1. export your Apple Music library to an xml file
1. copy your plex SQLITE database to the project
1. do a dry run on the script to see how well it matches your items
1. adjust matches using the data provided from the dry run
1. run the script to import the data
1. move your plex db back

## Setup

### Install dependencies

    brew install sqlite3
    bundle install

### Configuration

The project has a few things you can configure. You can adjust these in the `config/config.yml` file.

| key                  | type | info                                                                                                                            |
| -------------------- | ---- | ------------------------------------------------------------------------------------------------------------------------------- |
| minimum_plays        | int  | The minimum # of plays to consider a track for importing                                                                        |
| minimum_skips        | int  | The minimum # of plays to consider a track for importing                                                                        |
| default_date         | date | a date (yyyy-mm-dd) that the project will use to set a play or skip to if the data is not available from the Apple Music librar |
| account_id           | int  | your account id on your plex server                                                                                             |
| device_id            | int  | the device id you want your plays and skips to be attributed to                                                                 |
| import_skips         | bool | import track play counts                                                                                                        |
| import_plays         | bool | import track skip counts                                                                                                        |
| import_album_ratings | bool | import album ratings                                                                                                            |
| import_track_ratings | bool | import track ratings                                                                                                            |

Adjusting the `minimum_plays` and `minimum_skips` will be the difference between having a ton of songs (and work to do) matched into your Plex library, or having just a little bit.

**Play with these values a couple times with dry runs to see how many results you end up with.** Do this before you start the manual mapping step listed below.

#### Account & Device IDs

You're going to need to do a little research to get a few of these items. Mainly the `account_id` and `device_id`.

When doing a dry run, it will output a list of account and device ids. You can use these to set the values in the config file.

If there's only a single Account ID, then great, use that. If there's multiple, you'll probably want to use the lowest numbered one, as this is probably your main account if you are the server owner.

If there's multiple Device IDs, just pick any. On which device your imported plays will occur on, doens't really matter.

## Do the thing

OK, you can now get on with it.

### Exporting your Apple Music library

Dump your Apple Music library to an xml file and add it to the project.

1. Open the Music app on your desktop and go to File > Library > Export Library.
2. Rename the file to `apple-music.xml` and put it in the `config` directory of this project.

### Getting your Plex database

It's highly recommended to start this project with a copy of your Plex database. Run the dry runs over and over until you've adjusted matches to your liking. Once you've done that, you should feel safer at actually running the script on your real Plex database.

1. Export a Plex database backup at Plex > Settings > Troubleshooting
2. Rename the file to `plexdb.sqlite` and put it in the `config` directory of this project.

### Do a dry run

Doing a dry run will give you feedback on how well your Apple Music tracks are being matched to your Plex library tracks.

    script/dry_run

The script will dump a lot of information out including:

- How many tracks there are in total
- How many tracks will be attempted to be matched
- How many artists were not matched
- How many albums were not matched
- How many tracks were not matched

#### Matching Files

Additionally, it will dump 3 new files into the project. These files are mapping files that you can use to adjust the matches.

- `missing_artists.json`
- `missing_albums.json`
- `missing_tracks.json`

The key of the mapping files is value from Apple Music that will be used to find it in your Plex library. Overwrite the value to be what is in your Plex library, to help with matches.

For example, if your Apple Music has an artist of "Jay Z" and your Plex library has an artist of "JAY-Z", you would change the value in the mapping file to "JAY-Z".

```json
{ "Jay Z": "JAY-Z" }
```

#### Use the generated files to create mappings

Copy the generated files to the `config` directory and rename them. Then edit their values to create mappings.

- `missing_artists.json` -> `artist_mappings.json`
- `missing_albums.json` -> `album_mappings.json`
- `missing_tracks.json` -> `track_mappings.json`

Now, when you run the script again, it will use these mappings to help find matches.

##### Tips

Try fixing matches on artists first, this will go the longest way at getting more track matches. Once you have a good set of artist matches, move on to albums.

Here's a list of some reason you might not get a match, and what you need to look out for when resolving mappings.

- smart quotes - we attempt to correct these, but sometimes it doesn't work
- emm dashes - we attempt to correct these, but sometimes it doesn't work
- missing `The` in the title
- `…` vs `...`
- ` - EP` appended
- ` - Single` appended
- `Deluxe Edition` appended to the album name

You'll most likely see a ton of missing artists and albums due to the fact that your Plex library just doesn't have some of the modern music youv'e been listening to for the last few years you have been suffering through with streaming music.

There are many other reasons too. Just make a strong drink, open the text file in one window and your Plex library in another and get to work.

#### Do it for real

OK, so you've done a bunch of dry runs and you're happy with the match count. Let's do it for real now.

1. Stop Plex Server - this is critical
1. Find the production database file for Plex
   1. Make a copy of it, and never touch it again. It's crucial that you have a back up.
   1. Copy the original to your project directory and name it `plexdb.sqlite`
1. Run the script `script/run`

OK, you've imported your old metadata into

1. Rename your `plexdb.sqlite` back to the original name (`com.plexapp.plugins.library.db`)
1. Move it back to where it originally was (be careful of permission issues)
1. Start Plex server back up

### Enjoy

OK, that should be it. I'm sure a million problems will arise, but I did my best.
