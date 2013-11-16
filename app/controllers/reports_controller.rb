class ReportsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :ensure_dispatcher

  def ensure_dispatcher
    redirect_to edit_user_registration_path unless current_user.role == 'dispatcher'
  end

  def index
    @reports = Report.all
  end

  def create
    @report = Report.create(report_params)
    if @report.save
      render json: @report
    else
      render json: @report
    end
  end

  def update
    @report = Report.find(params[:id])
    @report.update_attributes(report_params)
  end


  def report_params
    params.require(:report).permit(:name, :phone, :lat, :long, :status, :description)
  end
end