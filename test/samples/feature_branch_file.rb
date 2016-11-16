class Signup 

  def self.chart_details(start_date, end_date, branch_id)
    signups = Signup.where('transaction_date >= ? and transaction_date <= ? and branch_id = ?', start_date, end_date, branch_id)
    signups_amount = signups.sum(&:paid_amount)
    chart_hash = { "Admission (Rs.#{signups_amount})" => signups.count }
    month = start_date.strftime('%B') + ' ' + "Total Collection (Rs. #{signups_amount})"
    [chart_hash, month]
  end

  def self.yearly_chart_details(start_date, end_date, branch_id)
    year = 'Yearly Graph for ' + start_date.strftime('%Y').to_s
    signups = Signup.where('transaction_date >= ? and transaction_date <= ? and branch_id = ?', start_date, end_date, branch_id)
    grouped_signups = signups.group_by { |m| m.transaction_date.beginning_of_month.strftime('%b') }
    admission_amount = []
    Date::ABBR_MONTHNAMES.compact.each do |month|
      grouped_signups[month] ? admission_amount.push(grouped_signups[month].sum(&:paid_amount)) : admission_amount.push(0)
    end
    [admission_amount.to_json,  year]
  end
end