module TimeUtil
  class << self
    def work_days(start_time, end_time)
      total_days = (end_time - start_time) / 1.day
      no_work_days = start_time.to_date.upto(end_time.to_date).count do |time|
        time.saturday? || time.sunday? || HolidayJapan.check(time)
      end

      total_days - no_work_days
    end
  end
end
