# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for dynamic methods in `Reports::MonthlyGpoLetterRequestsReport`.
# Please instead update this file by running `bin/tapioca dsl Reports::MonthlyGpoLetterRequestsReport`.


class Reports::MonthlyGpoLetterRequestsReport
  class << self
    sig do
      params(
        _date: T.untyped,
        start_time: T.untyped,
        end_time: T.untyped,
        block: T.nilable(T.proc.params(job: Reports::MonthlyGpoLetterRequestsReport).void)
      ).returns(T.any(Reports::MonthlyGpoLetterRequestsReport, FalseClass))
    end
    def perform_later(_date, start_time: T.unsafe(nil), end_time: T.unsafe(nil), &block); end

    sig { params(_date: T.untyped, start_time: T.untyped, end_time: T.untyped).returns(T.untyped) }
    def perform_now(_date, start_time: T.unsafe(nil), end_time: T.unsafe(nil)); end
  end
end
