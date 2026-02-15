# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Poly::Joins do
  describe '.joins_commentable' do
    it 'is defined on Comment' do
      expect(Comment).to respond_to(:joins_commentable)
    end

    it 'returns an ActiveRecord::Relation when joining Post' do
      result = Comment.joins_commentable(Post)

      expect(result).to be_a(ActiveRecord::Relation)
    end

    it 'returns an ActiveRecord::Relation when joining User' do
      result = Comment.joins_commentable(User)

      expect(result).to be_a(ActiveRecord::Relation)
    end

    it 'generates correct SQL for Post join' do
      sql = Comment.joins_commentable(Post).to_sql

      expect(sql).to include('INNER JOIN "posts"')
      expect(sql).to include('"comments"."commentable_id" = "posts"."id"')
      expect(sql).to include('commentable_type')
      expect(sql).to include('Post')
    end

    it 'generates correct SQL for User join' do
      sql = Comment.joins_commentable(User).to_sql

      expect(sql).to include('INNER JOIN "users"')
      expect(sql).to include('"comments"."commentable_id" = "users"."id"')
      expect(sql).to include('User')
    end

    it 'is chainable with other scopes' do
      result = Comment.joins_commentable(Post).where(posts: { title: 'Hello' })

      expect(result).to be_a(ActiveRecord::Relation)
      expect(result.to_sql).to include('Hello')
    end

    it 'raises ArgumentError for a class without reverse association' do
      stub_const('Unrelated', Class.new(ApplicationRecord) do
        self.table_name = 'posts'
      end)

      expect { Comment.joins_commentable(Unrelated) }.to raise_error(
        ArgumentError,
        %r{Unrelated must declare has_one/has_many as: :commentable}
      )
    end

    it 'does not define duplicate methods on repeated include' do
      expect { Comment.include(described_class) }.not_to raise_error
      expect(Comment).to respond_to(:joins_commentable)
    end
  end

  describe 'integration' do
    it 'fetches correct records through polymorphic join on Post' do
      post = create(:post, title: 'Joined Post')
      other_post = create(:post, title: 'Other Post')
      user = create(:user)

      comment_on_post = create(:comment, body: 'on post', commentable: post)
      create(:comment, body: 'on other post', commentable: other_post)
      create(:comment, body: 'on user', commentable: user)

      results = Comment.joins_commentable(Post).where(posts: { id: post.id })

      expect(results).to contain_exactly(comment_on_post)
    end

    it 'fetches correct records through polymorphic join on User' do
      post = create(:post)
      user = create(:user, name: 'Joined User')

      create(:comment, body: 'on post', commentable: post)
      comment_on_user = create(:comment, body: 'on user', commentable: user)

      results = Comment.joins_commentable(User).where(users: { id: user.id })

      expect(results).to contain_exactly(comment_on_user)
    end

    it 'returns all comments for a given type' do
      post1 = create(:post)
      post2 = create(:post)
      user = create(:user)

      comment1 = create(:comment, commentable: post1)
      comment2 = create(:comment, commentable: post2)
      create(:comment, commentable: user)

      results = Comment.joins_commentable(Post)

      expect(results).to contain_exactly(comment1, comment2)
    end
  end
end
