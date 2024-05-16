
class String
  def sanitize_for_finding
    self.gsub("'", "’").gsub("-", "‐").strip
  end
end

class PlexMetadataItemSetting < ActiveRecord::Base
  self.table_name = 'metadata_item_settings'
end

class PlexMetadataItemView < ActiveRecord::Base
  self.table_name = 'metadata_item_views'
end

class PlexMetadataItem < ActiveRecord::Base
   class << self
     def instance_method_already_implemented?(method_name)
       return true if method_name == 'hash'
       super
     end
   end

  self.table_name = 'metadata_items'

  artist_mappings_path = File.join(File.dirname(__FILE__), "../config/artist_mapping.json")
  album_mappings_path = File.join(File.dirname(__FILE__), "../config/album_mapping.json")
  track_mappings_path = File.join(File.dirname(__FILE__), "../config/track_mapping.json")
  ARTIST_MAPPING = File.exist?(artist_mappings_path) ? JSON.parse(File.read(artist_mappings_path)) : {}
  ALBUM_MAPPING = File.exist?(album_mappings_path) ? JSON.parse(File.read(album_mappings_path)) : {}
  TRACK_MAPPING = File.exist?(track_mappings_path) ? JSON.parse(File.read(track_mappings_path)) : {}
end

class PlexArtist < PlexMetadataItem
  has_many :albums, :foreign_key => "parent_id", :class_name => "PlexAlbum"
  default_scope { where("metadata_type = 8") }

  def self.find_by_name(name)
    sanitized_name = ARTIST_MAPPING[name] || name.sanitize_for_finding
    where("lower(title) = ?", sanitized_name.downcase).first
  end
end

class PlexAlbum < PlexMetadataItem
  belongs_to :artist, :foreign_key => "parent_id", :class_name => "PlexArtist", :inverse_of => :albums
  has_many :tracks, :foreign_key => "parent_id", :class_name => "PlexTrack"
  has_one :metadata_item_setting, :primary_key => "guid", :foreign_key => "guid", :class_name => "PlexMetadataItemSetting"
  default_scope { where("metadata_type = 9") }

  def self.find_by_name(name)
    sanitized_name = ALBUM_MAPPING[name] || name.sanitize_for_finding
    where("lower(title) = ?", sanitized_name.downcase).first
  end

  def set_rating(rating, account_id)
    self.build_metadata_item_setting unless self.metadata_item_setting
    self.metadata_item_setting.update(rating: rating, account_id: account_id)
  end
end

class PlexTrack < PlexMetadataItem
  belongs_to :album, :foreign_key => "parent_id", :class_name => "PlexAlbum", :inverse_of => :tracks
  has_one :metadata_item_setting, :primary_key => "guid", :foreign_key => "guid", :class_name => "PlexMetadataItemSetting"
  has_many :metadata_item_views, :primary_key => "guid", :foreign_key => "guid", :class_name => "PlexMetadataItemView"
  default_scope { where("metadata_type = 10") }

  def self.find_by_name(name)
    sanitized_name = TRACK_MAPPING[name] || name.sanitize_for_finding
    where("lower(title) = ?", sanitized_name.downcase).first
  end

  def self.find_by_name_and_artist_name(name, artist_name)
    sanitized_name = TRACK_MAPPING[name] || name.sanitize_for_finding
    sanitized_artist_name = ARTIST_MAPPING[artist_name] || artist_name.sanitize_for_finding
    where("lower(title) = ? AND lower(original_title) = ?", sanitized_name.downcase, sanitized_artist_name.downcase).first
  end

  def set_rating(rating, account_id)
    self.build_metadata_item_setting unless self.metadata_item_setting
    self.metadata_item_setting.update(rating: rating, account_id: account_id)
  end

  def add_listen_at(datetime, account_id, device_id)
    self.metadata_item_views.create(thumb_url: "", account_id: account_id, guid: self.guid, metadata_type: 10, library_section_id: self.library_section_id, grandparent_title: self.album.artist.title, parent_index: self.album.index, parent_title: self.album.title, index: self.index, title: self.title, viewed_at: datetime.to_i, grandparent_guid: self.album.artist.guid, device_id: device_id)
    
    self.build_metadata_item_setting unless self.metadata_item_setting
    self.metadata_item_setting.update(view_count: (self.metadata_item_setting.view_count || 0) + 1, last_viewed_at: datetime.to_i)
  end

  def add_skip_at(datetime, account_id, device_id)
    self.build_metadata_item_setting unless self.metadata_item_setting
    self.metadata_item_setting.update(skip_count: (self.metadata_item_setting.skip_count || 0) + 1, last_skipped_at: datetime.to_i)
  end
end

