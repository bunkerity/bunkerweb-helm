# BunkerWeb Helm Chart Documentation

## Documentation Structure

```
docs/
├── README.md              # This file
└── values.md              # User guide + technical reference (generated)
```

## Generating Documentation

This chart includes tools for automatic documentation generation:

```bash
# Generate values reference from values.yaml
python3 scripts/generate-docs.py
```

## Upgrading to 1.3.1

Chart 1.3.1 renders each env name once per container: an `extraEnvs` entry replaces the chart's entry of the same name, and a name repeated inside `extraEnvs` keeps its last value. A release whose deployed manifest renders a name twice in one container loses that variable on the first `helm upgrade` to 1.3.1, because Helm deletes it by name, and its pods run without it until a second identical `helm upgrade`. This hits an `extraEnvs` name the chart also sets (`SERVER_NAME`, `MULTISITE`, `LOG_TYPES`, ...), a name repeated inside `extraEnvs`, and a release that went from 1.3.0 to an unreleased `dev` chart with the `ACCESS_LOG_1`/`ERROR_LOG_1`/`LOG_TYPES`/`LOG_SYSLOG_ADDRESS` workaround (#142).

Follow these steps in order, whatever the mix of affected workloads (Deployments, a DaemonSet or StatefulSet). Each step runs for all of them before the next starts. Step 6 restores a DaemonSet with `--set-json`, which needs Helm 3.10 or later, and step 4 can add `--reset-then-reuse-values`, which needs Helm 3.14 or later: check `helm version` before step 3.

**1. Check.** It reads the last `deployed` revision, not the latest one (which can be `failed`), prints `Kind/name container: VARIABLE` for each name rendered twice in one container, then a count. An error message means the release or its deployed revision cannot be read: fix that first, do not upgrade. With a count of 0, upgrade as usual and stop here.

```bash
REV=$(helm history RELEASE -n NAMESPACE -o yaml | awk '{sub(/^[- ]+/,"")} /^revision:/ {r=$2} /^status: deployed/ {d=r} END {print d}') &&
[ -n "$REV" ] && M=$(helm get manifest RELEASE -n NAMESPACE --revision "$REV") && [ -n "$M" ] &&
printf '%s\n' "$M" | awk -v rev="$REV" '
/^---/ {kind=name=""; inenv=0; next}
/^kind:/ {kind=$2; next}
/^  name:/ && !name {name=$2; next}
/^ *(#.*)?$/ {next}
{ind=match($0,/[^ ]/)-1
 if (inenv && !(ind>e || (ind==e && /^ *-/))) inenv=0
 if (/^ *- name:/) {n=$0; sub(/^ *- name: */,"",n); gsub(/["\047 ]/,"",n)
   if (inenv) seen[kind "/" name " " c ": " n]++; else dash[ind]=n}
 if (/^ *env: *$/) {e=ind; inenv=1; c=dash[e-2]}}
END {for (k in seen) if (seen[k]>1) {print k; n++}; print "revision " rev ": " n+0 " duplicate(s)"}' ||
{ echo "cannot read the deployed revision of RELEASE" >&2; false; }
```

**2. Record** the whole update strategy of each listed DaemonSet and StatefulSet, and keep the output (`KIND/NAME` is the start of a listed line). A StatefulSet may carry a `partition` that steps 3 and 6 must not lose.

```bash
kubectl -n NAMESPACE get KIND/NAME -o jsonpath='{.spec.updateStrategy}{"\n"}'
```

**3. Prepare** every listed Deployment and StatefulSet. Paused or `OnDelete`, no pod is replaced between the two upgrades. A DaemonSet needs no command here: the `--set` of step 4 switches it (the chart has no strategy value for a StatefulSet, hence the patch).

```bash
kubectl -n NAMESPACE rollout pause deployment/NAME   # each listed Deployment
kubectl -n NAMESPACE patch statefulset/NAME --type merge -p '{"spec":{"updateStrategy":{"type":"OnDelete","rollingUpdate":null}}}'   # each listed StatefulSet
```

**4. Upgrade twice** with the same command: the first removes the variable, the second restores one entry. `<your usual flags>` are the flags you always pass to `helm upgrade`, without `--wait`, `--atomic` or `--force` even if you usually pass them: a paused Deployment never becomes ready, so the upgrade times out and marks the release `failed`, the `--atomic` rollback then fails on `$setElementOrder`, and `--force` fails on the bundled MariaDB PVC. Leave out the `--set` when no DaemonSet is listed, and change nothing else. When a DaemonSet is listed, remove from your flags each assignment to `bunkerweb.updateStrategy`, and only that assignment: `--set bunkerweb.kind=DaemonSet,bunkerweb.updateStrategy.type=RollingUpdate` becomes `--set bunkerweb.kind=DaemonSet`. Helm applies `--set-json`, then `--set`, then `--set-string`, wherever they appear on the command line, so an assignment of yours could replace the `OnDelete` here or the recorded strategy in step 6. A strategy in a values file is fine: these flags override it. If your flags then supply no values (no `--set` flag of any kind, no `-f` or `--values` file that sets a value; a file holding only `{}` or comments sets none) and pick no values mode (`--reuse-values`, `--reset-values`, `--reset-then-reuse-values`), add `--reset-then-reuse-values` (Helm 3.14 or later): the guide's `--set` alone would make Helm drop your stored values, and this flag keeps them on top of the new chart's defaults. Every later `helm upgrade` here repeats these flags unchanged.

```bash
helm upgrade RELEASE CHART -n NAMESPACE <your usual flags> --set bunkerweb.updateStrategy.type=OnDelete
```

**5. Verify** before restoring anything, once per line step 1 listed. It must print exactly one line, and that line must be your `extraEnvs` entry, keys sorted, plus any default Kubernetes fills in: `{"name":"MULTISITE","value":"yes"}`, or `{"name":"ACCESS_LOG_1","valueFrom":{"fieldRef":{"apiVersion":"v1","fieldPath":"metadata.namespace"}}}` for `fieldRef: {fieldPath: metadata.namespace}`. No line: run step 4 once more and verify again. Two lines, or another entry: stop and ask.

```bash
kubectl -n NAMESPACE get KIND/NAME -o jsonpath='{range .spec.template.spec.containers[?(@.name=="CONTAINER")].env[?(@.name=="VARIABLE")]}{@}{"\n"}{end}'
```

**6. Restore and roll out.** Put back each strategy recorded in step 2, then resume the Deployments. A `RollingUpdate` workload: Kubernetes replaces its pods itself, within `maxUnavailable` and `partition` (pods below the partition stay), and you wait for it. An `OnDelete` workload is restored but not waited for (`rollout status` rejects it): its pods keep the pre-upgrade template, variable included, until you replace them. Replace them one at a time: delete one pod owned by that workload, wait until the pod replacing it is Ready (same name for a StatefulSet, same node for a DaemonSet), then delete the next. Each replacement gets the single entry. A DaemonSet: step 4 with its `--set` replaced by `--set-json`, `SAVED` being the JSON recorded in step 2. A StatefulSet: patch back the same JSON. At the end, step 2 must print what you recorded.

```bash
helm upgrade RELEASE CHART -n NAMESPACE <your usual flags> --set-json 'bunkerweb.updateStrategy=SAVED'   # each listed DaemonSet
kubectl -n NAMESPACE patch statefulset/NAME --type merge -p '{"spec":{"updateStrategy":SAVED}}'   # each listed StatefulSet
kubectl -n NAMESPACE rollout resume deployment/NAME   # each paused Deployment
kubectl -n NAMESPACE rollout status KIND/NAME --timeout=300s   # each listed workload not recorded as OnDelete
```

Without these steps the second upgrade still restores the variable, but the pods run without it until then. The steps were run end to end from a clean 1.3.0 install on three setups, next to an unrelated release left untouched: a scheduler Deployment and a DaemonSet worker (`secretKeyRef`, live `maxUnavailable: 1` against a stored 2), the same DaemonSet recorded as `OnDelete` (`fieldRef`), and a StatefulSet recorded as `OnDelete`. Earlier runs covered `partition: 1` and `--reuse-values`. The UI, API and controller Deployments share the Helm patch but were not run.

## Contributing

When contributing to this chart, please:

1. Update relevant documentation
2. Run the documentation generator
3. Test examples and configurations
4. Follow the existing style and structure

## External Resources

- **[BunkerWeb Official Docs](https://docs.bunkerweb.io/)** - Complete product documentation
- **[GitHub Repository](https://github.com/bunkerity/bunkerweb)** - Source code and issues
- **[Community Forum](https://github.com/bunkerity/bunkerweb/discussions)** - Community support
- **[Helm Charts Repository](https://github.com/bunkerity/bunkerweb-helm)** - Chart source

## License

This documentation is part of the BunkerWeb Helm Chart project and follows the same licensing terms as the main project.
