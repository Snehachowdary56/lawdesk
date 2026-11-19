require "test_helper"

class DocumentSearchTest < ActiveSupport::TestCase
  setup do
    @lease = make_matter(title: "Lease dispute")
    @estate = make_matter(title: "Estate of R. Patel", practice_area: "Wills and Estates")
    @lease.documents.create!(title: "Notice of termination", body: "The landlord served notice to terminate the commercial lease for unpaid rent.")
    @lease.documents.create!(title: "Repair invoices", body: "Invoices for roof repairs paid by the tenant in August.")
    @estate.documents.create!(title: "Last will", body: "The testator leaves the residue of the estate to her children in equal shares.")
    DocumentSearch.refresh!
  end

  test "finds documents by meaning of words (stemming) and ranks title matches higher" do
    results = DocumentSearch.search("terminated leases")
    assert_equal "Notice of termination", results.first[:title]
    assert_includes results.first[:snippet], "<em>"
  end

  test "tolerates typos" do
    assert_equal "Last will", DocumentSearch.search("testatr").first[:title]
  end

  test "filters to one matter" do
    results = DocumentSearch.search("invoices estate", matter_id: @estate.id)
    assert(results.all? { |r| r[:matter_id] == @estate.id })
  end

  test "deleted documents disappear from search" do
    @estate.documents.destroy_all
    DocumentSearch.refresh!
    assert_empty DocumentSearch.search("testator")
  end
end
