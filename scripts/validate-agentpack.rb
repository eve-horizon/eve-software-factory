#!/usr/bin/env ruby

require "pathname"
require "yaml"

root = Pathname.new(ARGV.fetch(0, Pathname.new(__dir__).join("..").to_s)).expand_path

def fail!(message)
  warn "ERROR: #{message}"
  exit 1
end

def load_yaml(path)
  YAML.safe_load(path.read, permitted_classes: [], permitted_symbols: [], aliases: true)
rescue Psych::Exception => e
  fail!("#{path}: invalid YAML: #{e.message}")
end

required = %w[
  eve/pack.yaml
  eve/agents.yaml
  eve/teams.yaml
  eve/chat.yaml
  eve/x-eve.yaml
]
required.each do |relative|
  fail!("missing #{relative}") unless root.join(relative).file?
end

pack = load_yaml(root.join("eve/pack.yaml"))
fail!("pack version must be 1") unless pack["version"] == 1
fail!("pack id must be software-factory") unless pack["id"] == "software-factory"
fail!("gateway default must hide pack agents") unless pack.dig("gateway", "default_policy") == "none"

expected_imports = {
  "agents" => "eve/agents.yaml",
  "teams" => "eve/teams.yaml",
  "chat" => "eve/chat.yaml",
  "x_eve" => "eve/x-eve.yaml"
}
fail!("pack imports do not match the canonical files") unless pack["imports"] == expected_imports
expected_imports.each_value do |relative|
  fail!("import does not resolve: #{relative}") unless root.join(relative).file?
end

agents_doc = load_yaml(root.join("eve/agents.yaml"))
fail!("agents schema version must be 1") unless agents_doc["version"] == 1
agents = agents_doc.fetch("agents", {})
expected_agents = %w[factory_pm factory_planner factory_coder factory_verifier]
fail!("factory agent roster drifted") unless agents.keys.sort == expected_agents.sort

slug_pattern = /^[a-z0-9][a-z0-9-]*$/
agents.each do |id, agent|
  fail!("#{id}: invalid slug") unless agent.fetch("slug", "").match?(slug_pattern)
  skill = agent.fetch("skill", "")
  fail!("#{id}: missing skill #{skill}") unless root.join("skills", skill, "SKILL.md").file?
  fail!("#{id}: invalid permission policy") unless %w[auto_edit never yolo].include?(agent.dig("policies", "permission_policy"))
  fail!("#{id}: invalid commit policy") unless %w[never manual auto required].include?(agent.dig("policies", "git", "commit"))
  fail!("#{id}: invalid push policy") unless %w[never on_success required].include?(agent.dig("policies", "git", "push"))
end
fail!("factory PM must be routable") unless agents.dig("factory_pm", "gateway", "policy") == "routable"
(expected_agents - ["factory_pm"]).each do |id|
  fail!("#{id}: worker agents must inherit the hidden pack default") if agents[id].key?("gateway")
end

teams_doc = load_yaml(root.join("eve/teams.yaml"))
fail!("teams schema version must be 1") unless teams_doc["version"] == 1
factory = teams_doc.dig("teams", "factory") || fail!("factory team missing")
fail!("factory relay lead mismatch") unless factory["lead"] == "factory_pm"
fail!("factory relay member mismatch") unless factory["members"] == expected_agents.drop(1)
fail!("factory dispatch must be relay") unless factory.dig("dispatch", "mode") == "relay"
(Array(factory["members"]) + [factory["lead"]]).each do |id|
  fail!("factory team references unknown agent #{id}") unless agents.key?(id)
end

chat_doc = load_yaml(root.join("eve/chat.yaml"))
fail!("chat schema version must be 1") unless chat_doc["version"] == 1
routes = Array(chat_doc["routes"])
route = routes.find { |candidate| candidate["id"] == "route_factory" }
fail!("factory route missing") unless route
fail!("factory route target mismatch") unless route["target"] == "team:factory"
begin
  Regexp.new(route.fetch("match"))
rescue RegexpError => e
  fail!("factory route regex is invalid: #{e.message}")
end

x_eve = load_yaml(root.join("eve/x-eve.yaml"))
profiles = x_eve.dig("agents", "profiles") || fail!("harness profiles missing")
defaults = x_eve.dig("agents", "defaults") || fail!("agent defaults missing")
fail!("default harness profile is undefined") unless profiles.key?(defaults["harness_profile"])
agents.each do |id, agent|
  fail!("#{id}: undefined harness profile") unless profiles.key?(agent["harness_profile"])
end

supported_models = {
  "claude" => ["opus-4.5"],
  "codex" => ["gpt-5.2-codex"]
}
profiles.each do |name, candidates|
  fail!("#{name}: profile must have candidates") unless candidates.is_a?(Array) && !candidates.empty?
  candidates.each do |candidate|
    harness = candidate["harness"]
    model = candidate["model"]
    fail!("#{name}: unsupported harness #{harness}") unless supported_models.key?(harness)
    fail!("#{name}: model #{model} is not source-backed for #{harness}") unless supported_models[harness].include?(model)
    fail!("#{name}: invalid reasoning effort") unless %w[low medium high x-high].include?(candidate["reasoning_effort"])
  end
end

skill_names = []
root.glob("skills/*/SKILL.md").sort.each do |skill_path|
  raw = skill_path.read
  match = raw.match(/\A---\s*\n(.*?)\n---\s*\n/m)
  fail!("#{skill_path}: missing YAML frontmatter") unless match
  frontmatter = YAML.safe_load(match[1], permitted_classes: [], permitted_symbols: [], aliases: false)
  expected_name = skill_path.dirname.basename.to_s
  fail!("#{skill_path}: frontmatter name must be #{expected_name}") unless frontmatter["name"] == expected_name
  fail!("#{skill_path}: description is required") if frontmatter.fetch("description", "").strip.empty?
  skill_names << frontmatter["name"]
  raw.scan(/`(references\/[A-Za-z0-9._\/-]+)`/).flatten.each do |reference|
    fail!("#{skill_path}: missing #{reference}") unless skill_path.dirname.join(reference).file?
  end
end
fail!("duplicate skill names") unless skill_names.uniq.length == skill_names.length
fail!("skill roster does not match agents") unless skill_names.sort == agents.values.map { |agent| agent["skill"] }.sort

puts "AgentPack validation passed: #{agents.length} agents, 1 relay team, #{routes.length} route, #{skill_names.length} skills"
