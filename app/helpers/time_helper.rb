module TimeHelper
  def time_tag_ago(datetime)
    return "—" if datetime.nil?

    time_tag datetime, "#{time_ago_in_words(datetime)} ago",
      title: datetime.strftime("%B %-d, %Y %-l:%M %p %Z")
  end
end
