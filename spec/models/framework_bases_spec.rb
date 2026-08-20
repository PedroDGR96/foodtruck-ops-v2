require "rails_helper"

RSpec.describe "Framework base classes" do
  it "keeps the application record abstract" do
    expect(ApplicationRecord.abstract_class?).to be(true)
  end

  it "uses Rails controller and job bases" do
    expect(ApplicationController).to be < ActionController::Base
    expect(ApplicationJob).to be < ActiveJob::Base
  end

  it "uses the configured mailer base" do
    expect(ApplicationMailer).to be < ActionMailer::Base
    expect(ApplicationMailer.default_params).to include(from: "from@example.com")
  end
end
