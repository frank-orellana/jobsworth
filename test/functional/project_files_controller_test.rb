require 'test_helper'

class ProjectFilesControllerTest < ActionController::TestCase
  fixtures :users, :companies, :tasks, :customers, :projects

  def setup
    @request.with_subdomain('cit')
    @user = users(:admin)
    sign_in @user
    @request.session[:user_id] = @user.id
    @user.company.create_default_statuses

    @task = Task.first
    @task.users << @task.company.users
    @task.save!
  end

  teardown do
    @task.attachments.destroy_all
  end

  should "be able to display attachments which has old naming conventions (without md5 checksum)" do
    #2 task attachments with old naming convention (without md5 cheksum)
    {'suri cruise.jpg' => 'de200546ed2916143708f30cc7bd77fb', '"an file with spaces and quote.jpeg"' => 'bb0eb4488dfddb7e07a9824e3e29586b'}.each do |attachment, uri|
      attachment = @task.attachments.make(:company => @user.company,
                             :customer => @task.project.customer,
                             :project => @task.project,
                             :user_id => @user.id,
                             :file => Rails.root.join("test", "fixtures", "files", attachment).open,
                             :uri => uri)
      old_uri = "#{attachment.id}_#{attachment.file_file_name}".gsub(' ', '_').gsub(/[^a-zA-Z0-9_\.]/, '')
      File.rename attachment.file_path, attachment.file_path.gsub(attachment.uri, old_uri.gsub(/#{File.extname(old_uri)}$/, ""))
      File.rename attachment.thumbnail_path, attachment.thumbnail_path.gsub(attachment.uri, old_uri.gsub(/#{File.extname(old_uri)}$/, ""))
      attachment.update_attribute(:uri, old_uri)
    end
    
    @task.attachments.each do |attachment|
      get :show, :id => "#{attachment.id}.#{attachment.file_extension}"
      assert_response :success

      get :download, :id => "#{attachment.id}.#{attachment.file_extension}"
      assert_response :success
    end
  end

  should "delete the file on disk if other tasks aren't linked to the same file" do
    @task.attachments.make(:company => @user.company,
                           :customer => @task.project.customer,
                           :project => @task.project,
                           :user_id => @user.id,
                           :file => Rails.root.join("test", "fixtures", "files", 'rails.png').open,
                           :uri => "450fc241fab7867e96536903244087f4")
    assert_equal true, File.exists?("#{Rails.root}/store/450fc241fab7867e96536903244087f4_original.png")
    assert_equal true, File.exists?("#{Rails.root}/store/450fc241fab7867e96536903244087f4_thumbnail.png")

    assert_difference("ProjectFile.count", -1) do
      delete :destroy_file, :id => @task.attachments.first.id
    end
    assert_equal false, File.exists?("#{Rails.root}/store/450fc241fab7867e96536903244087f4_original.png")
    assert_equal false, File.exists?("#{Rails.root}/store/450fc241fab7867e96536903244087f4_original.png")
  end

  should "not delete the file on disk if other tasks are linked to the same file" do
    @task.attachments.make(:company => @user.company,
                           :customer => @task.project.customer,
                           :project => @task.project,
                           :user_id => @user.id,
                           :file => Rails.root.join("test", "fixtures", "files", 'suri cruise.jpg').open,
                           :uri => "8e732963114deed0079975414a0811b3")

    @second_task = Task.last
    @second_task.users << @second_task.company.users
    @second_task.save!
    @second_task.attachments.make(:company => @user.company,
                           :customer => @second_task.project.customer,
                           :project => @second_task.project,
                           :user_id => @user.id,
                           :file => Rails.root.join("test", "fixtures", "files", 'suri cruise.jpg').open,
                           :uri => "8e732963114deed0079975414a0811b3")

    assert_equal true, File.exists?("#{Rails.root}/store/8e732963114deed0079975414a0811b3_original.jpg")
    assert_equal true, File.exists?("#{Rails.root}/store/8e732963114deed0079975414a0811b3_thumbnail.jpg")

    assert_difference("ProjectFile.count", -1) do
      delete :destroy_file, :id => @second_task.attachments.first.id
    end
    assert_equal true, File.exists?("#{Rails.root}/store/8e732963114deed0079975414a0811b3_original.jpg")
    assert_equal true, File.exists?("#{Rails.root}/store/8e732963114deed0079975414a0811b3_thumbnail.jpg")
  end
end
