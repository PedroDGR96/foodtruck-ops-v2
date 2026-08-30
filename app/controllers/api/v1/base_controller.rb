module Api
  module V1
    class Unauthorized < StandardError; end

    class Forbidden < StandardError; end

    class BaseController < ActionController::API
      include Authentication
      include Pundit::Authorization

      rescue_from Api::V1::Unauthorized, with: :render_unauthorized
      rescue_from Api::V1::Forbidden, with: :render_forbidden
      rescue_from Pundit::NotAuthorizedError, with: :render_forbidden
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActionController::ParameterMissing, with: :render_bad_request
      rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable
      rescue_from OrderLifecycle::IllegalTransition, with: :render_unprocessable_message
      rescue_from CashRegister::ShiftError, with: :render_unprocessable_message

      private

      def paginate(scope)
        page = params.fetch(:page, 1).to_i
        page = 1 if page < 1
        per_page = params.fetch(:per_page, 25).to_i.clamp(1, 100)
        total = scope.count
        records = scope.limit(per_page).offset((page - 1) * per_page)
        @pagination = {
          page: page,
          per_page: per_page,
          total_count: total,
          total_pages: (total.to_f / per_page).ceil
        }
        records
      end

      def render_collection(records)
        response.headers["X-Page"] = @pagination[:page].to_s
        response.headers["X-Per-Page"] = @pagination[:per_page].to_s
        response.headers["X-Total-Count"] = @pagination[:total_count].to_s
        response.headers["X-Total-Pages"] = @pagination[:total_pages].to_s
        render json: { data: records.as_json, meta: @pagination }, status: :ok
      end

      def render_record(record, status: :ok)
        render json: { data: record.as_json }, status: status
      end

      def render_unauthorized(exception)
        render json: { error: exception.message }, status: :unauthorized
      end

      def render_forbidden(exception)
        render json: { error: exception.message }, status: :forbidden
      end

      def render_not_found(_exception)
        render json: { error: "Not found" }, status: :not_found
      end

      def render_bad_request(exception)
        render json: { error: exception.message }, status: :bad_request
      end

      def render_unprocessable(exception)
        render json: { errors: exception.record.errors.full_messages }, status: :unprocessable_content
      end

      def render_unprocessable_message(exception)
        render json: { error: exception.message }, status: :unprocessable_content
      end
    end
  end
end
