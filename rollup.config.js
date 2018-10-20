import resolve from 'rollup-plugin-node-resolve';

export default {
  input: 'src/client.js',
  output: {
    file: 'dist/comms.js',
    format: 'umd',
    name: 'comms'
  },
  plugins: [ resolve() ]
};
