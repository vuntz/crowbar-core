# Copyright (c) 2016 SUSE Linux GmbH.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module CrowbarRoleRecipe
  # Helper to decide whether a role should be run for a node, depending on the
  # state of the node.
  def self.node_state_valid_for_role?(node, barclamp, role)
    if node[:state] == "applying"
      # we always want deployer-client, both for heartbeat but also because it
      # sets up the ability to use the barclamp library
      if role == "deployer-client" || \
          (node["crowbar"]["applying_for"].key?(barclamp) && \
           node["crowbar"]["applying_for"][barclamp].include?(role))
         return true
       else
         roles = node["crowbar"]["applying_for"].collect { |k, v| v }.flatten.sort.uniq
         Chef::Log.info("Skipping role \"#{role}\" because node is applying. " \
             "Only the following roles are considered: #{roles.join}.")
         return false
       end
    end

    if node.key? barclamp
      states_for_role = if node[barclamp].key? "element_states"
        # if nil, then this means all states are valid
        node[barclamp]["element_states"][role]
      else
        ["all"]
      end

      return true if states_for_role.nil? ||
          states_for_role.include?("all") ||
          states_for_role.include?(node[:state])

      Chef::Log.info("Skipping role \"#{role}\" because node is in state \"#{node[:state]}\". " \
        "Role \"#{role}\" only applies in the following states: #{states_for_role.join(", ")}.")
    else
      # Generally speaking, if we don't even have attributes related to the
      # barclamp, then it means the role should not even be there.
      # There's one exception, though: when bootstrapping the admin server,
      # this happens for a couple of roles.
      return true if node["crowbar"]["admin_node"] &&
          ["crowbar", "deployer-client"].include?(role)

      Chef::Log.info("Skipping role \"#{role}\" because node does not have applied proposal for #{role} in its runlist.")
    end

    false
  end
end
