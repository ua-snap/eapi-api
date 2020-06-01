set -x
set -v
echo "Running NCL..."
mkdir -p /tmp/87229f5b39a480eb31796e8e35cf908e
export NCL_OUTPUT_DIR=/tmp/87229f5b39a480eb31796e8e35cf908e/
eval "$(conda shell.bash hook)"
conda activate ncl_stable

# Try running this before/after uncommenting next line.
# ncl test.ncl

echo "EXITING WITH EXIT CODE"
echo $?