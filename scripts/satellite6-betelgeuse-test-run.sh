rm -rf pylarion
git clone ${PYLARION_REPO_URL}

# Install pylarion and its dependencies
cd pylarion
git checkout origin/satelliteqe-pylarion
pip install -r requirements.txt
pip install .
cd ..

rm -rf betelgeuse
git clone https://github.com/SatelliteQE/betelgeuse.git
cd betelgeuse
git checkout xml-test-case
pip install -r requirements.txt
pip install .
cd ..

cat > .pylarion <<EOF
[webservice]
url=${POLARION_URL}
user=${POLARION_USER}
password=${POLARION_PASSWORD}
default_project=${POLARION_DEFAULT_PROJECT}
svn_repo=${POLARION_SVN_REPO}
use_logstash=false
EOF

TEST_TEMPLATE_ID="Empty"

# Create a new iteration for the current run
if [ ! -z "$POLARION_RELEASE" ]; then
    betelgeuse test-plan --name "${TEST_RUN_ID}" --parent-name "${POLARION_RELEASE}" \
        --plan-type iteration "${POLARION_DEFAULT_PROJECT}"
else
    betelgeuse test-plan --name "${TEST_RUN_ID}" \
        --plan-type iteration "${POLARION_DEFAULT_PROJECT}"
fi

POLARION_SELECTOR="name=Satellite 6"
SANITIZED_ITERATION_ID="$(echo ${TEST_RUN_ID} | sed 's|\.|_|g' | sed 's| |_|g')"

# Prepare the XML files
for tier in $(seq 1 4)
do
  for run in parallel sequential
  do
    betelgeuse --token-prefix="@" xml-test-run \
        --custom-fields="isautomated=true" \
        --custom-fields="arch=x8664" \
        --custom-fields="variant=server" \
        --custom-fields="plannedin=${SANITIZED_ITERATION_ID}" \
        --response-property="${POLARION_SELECTOR}" \
        --test-run-id "${TEST_RUN_ID} - ${run} - Tier ${tier}" \
        ./tier${tier}-${run}-results.xml \
        tests/foreman \
        "${POLARION_USER}" \
        "${POLARION_DEFAULT_PROJECT}" \
        polarion-tier${tier}-${run}-results.xml
    curl -k -u ${POLARION_USER}:${POLARION_PASSWORD} \
    -X POST \
    -F file=@polarion-tier${tier}-${run}-results.xml \
    "${POLARION_URL}import/xunit"
  done
done

# Mark the iteration done
betelgeuse test-plan \
    --name "${TEST_RUN_ID}" \
    --custom-fields status=done \
    "${POLARION_DEFAULT_PROJECT}"
