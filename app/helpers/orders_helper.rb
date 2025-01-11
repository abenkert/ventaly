module OrdersHelper
  def status_color_class(status)
    case status
    when 'pending'
      'bg-warning'
    when 'paid'
      'bg-success'
    when 'shipped'
      'bg-info'
    when 'completed'
      'bg-success'
    else
      'bg-secondary'
    end
  end

  def payment_status_color_class(status)
    case status&.downcase
    when 'complete', 'completed'
      'bg-success'
    when 'pending'
      'bg-warning'
    when 'incomplete'
      'bg-danger'
    else
      'bg-secondary'
    end
  end
end 