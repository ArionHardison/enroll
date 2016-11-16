# Given enrollment IDs, count heads
def count_members_for_hbx_ids(hbx_ids)
  auto_renew_member_count = Family.collection.aggregate([
    {"$match" => {"households.hbx_enrollments.hbx_id" => {"$in" => hbx_ids}}},
    {"$unwind" => "$households"},
    {"$unwind" => "$households.hbx_enrollments"},
    {"$match" => {"households.hbx_enrollments.hbx_id" => {"$in" => hbx_ids}, "households.hbx_enrollments.hbx_enrollment_members" => {"$ne" => nil}}},
    {"$project" => {"member_count" => {"$size" => "$households.hbx_enrollments.hbx_enrollment_members"}}},
    {"$group" => {"_id" => 1, "total_members" => {"$sum" => "$member_count"}}}
  ])

  auto_renew_member_count.first['total_members']
end

# Gimme all the 2017s
qs = Queries::PolicyAggregationPipeline.new

qs.filter_to_individual.filter_to_active.with_effective_date({"$gt" => Date.new(2016,12,31)}).eliminate_family_duplicates

qs.add({ "$match" => {"policy_purchased_at" => {"$gt" => Time.mktime(2016,11,1,0,0,0)}}})

enroll_pol_ids = []

qs.evaluate.each do |r|
  enroll_pol_ids << r['hbx_id']
end

all_ivl_count = enroll_pol_ids.count
puts "2017 Active Enrollment Count: #{all_ivl_count}"

# Select my auto renewals
qs = Queries::PolicyAggregationPipeline.new

qs.filter_to_individual.filter_to_active.with_effective_date({"$gt" => Date.new(2016,12,31)}).eliminate_family_duplicates

qs.add({ "$match" => {"policy_purchased_at" => {"$gt" => Time.mktime(2016,11,1,0,0,0)}}})

auto_renew_pol_ids = []

qs.evaluate.each do |r|
  if r['aasm_state'] == "auto_renewing"
    auto_renew_pol_ids << r['hbx_id']
  end
end

auto_renew_count = auto_renew_pol_ids.length
puts "Auto Renewed Enrollment Count: #{auto_renew_count}"

auto_renew_member_count = count_members_for_hbx_ids(auto_renew_pol_ids)
puts "Total passively renewed covered lives: #{auto_renew_member_count}"

# Select all the active selections
all_active_selections = enroll_pol_ids - auto_renew_pol_ids

puts "Total actively selected 2017 enrollments: #{all_active_selections.length}"

active_selection_member_count = count_members_for_hbx_ids(all_active_selections)
puts "Total actively selected covered lives: #{active_selection_member_count}"

# Select all the new renewals
active_selection_families = Family.where("households.hbx_enrollments.hbx_id" => {"$in" => all_active_selections})

active_selection_new_enrollments = []
active_selection_families.each do |fam|
  all_policies = fam.households.flat_map(&:hbx_enrollments)
  policy_for_2017 = all_policies.detect { |pol| all_active_selections.include?(pol.hbx_id) }
  found_a_2016 = all_policies.any? do |pol|
    (pol.effective_on <=  Date.new(2016,12,31)) &&
      (pol.effective_on >  Date.new(2015,12,31))
  end
  if !found_a_2016
    active_selection_new_enrollments << policy_for_2017.hbx_id
  end
end

puts "Total new 2017 enrollments: #{active_selection_new_enrollments.length}"

new_members_count = count_members_for_hbx_ids(active_selection_new_enrollments)
puts "Total new covered lives: #{new_members_count}"
