class CreateFollowings < ActiveRecord::Migration
  def self.up
    create_table :followings do |t|
      t.integer :follower_id
      t.integer :followed_user_id
      t.boolean :status
      t.timestamps
    end
  end

  def self.down
    drop_table :followings
  end
end
