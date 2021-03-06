# == Schema Information
#
# Table name: store_promotion_events
#
#  id               :bigint           not null, primary key
#  background_color :string(255)      default("#333333"), not null
#  expired_at       :datetime         not null
#  href             :string(255)      default("")
#  published_at     :datetime         not null
#  slug             :string(255)
#  title            :string(255)      not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  country_id       :bigint           not null
#
# Indexes
#
#  index_store_promotion_events_on_country_id  (country_id)
#  index_store_promotion_events_on_slug        (slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (country_id => countries.id)
#
module Store
  class PromotionEvent < NationRecord
    extend FriendlyId
    extend_has_one_attached :thumbnail
    extend_has_one_attached :banner_pc
    extend_has_one_attached :banner_mb
    friendly_id :title, use: %i[slugged finders history]

    has_many :event_section_connections, class_name: 'Store::SectionConnection'
    has_many :event_sections, class_name: 'Store::Section', through: :event_section_connections, dependent: :destroy

    has_many :sections, class_name: 'Store::Section', as: :attachable

    scope :active, ->(standard_time = Time.zone.now) { where('published_at < :now AND expired_at > :now', now: standard_time) }
  end
end
