#!/usr/bin/env bats

load test_helper

TEST_APP="rdmtestapp"

setup() {
  uninstall_k3s || true
  global_setup
  dokku nginx:stop
  export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
}

teardown() {
  global_teardown
  dokku nginx:start
  uninstall_k3s || true
}

@test "(scheduler-k3s) install bunkerweb and generate ingress class" {
  if [[ -z "$DOCKERHUB_USERNAME" ]] || [[ -z "$DOCKERHUB_TOKEN" ]]; then
    skip "skipping due to missing docker.io credentials DOCKERHUB_USERNAME:DOCKERHUB_TOKEN"
  fi

  INGRESS_CLASS=bunkerweb install_k3s

  # bunkerweb namespace should exist
  run /bin/bash -c "kubectl get ns bunkerweb -o name"
  echo "output: $output"
  echo "status: $status"
  assert_success
  assert_output_contains "namespace/bunkerweb"

  # ingress-nginx should NOT be installed
  run /bin/bash -c "kubectl get ns ingress-nginx -o name"
  echo "output: $output"
  echo "status: $status"
  [ "$status" -ne 0 ]

  # traefik should NOT be installed
  run /bin/bash -c "kubectl get ns traefik -o name"
  echo "output: $output"
  echo "status: $status"
  [ "$status" -ne 0 ]

  # Create and deploy a simple app and verify ingressClassName
  run /bin/bash -c "dokku apps:create $TEST_APP"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku domains:set $TEST_APP $TEST_APP.dokku.me"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku git:sync --build $TEST_APP https://github.com/dokku/smoke-test-app.git"
  echo "output: $output"
  echo "status: $status"
  assert_success

  # Wait briefly for resources to be applied
  run /bin/bash -c "sleep 20"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "kubectl get ingress -n $TEST_APP -o=jsonpath='{.items[0].spec.ingressClassName}'"
  echo "output: $output"
  echo "status: $status"
  assert_success
  assert_output "bunkerweb"
}
