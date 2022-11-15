import * as fs from 'fs';
import * as path from 'path';

export const getAbi = async (pathname: string) => {
  const contract_abi = await JSON.parse(
    await fs.readFileSync(path.join(__dirname, '../../', pathname), 'utf-8'),
  );

  return contract_abi;
};
