----------
-- INITIAL CHECKS
----------

SELECT COUNT(UniqueID) FROM HouseData;

SELECT *
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'HouseData';

SELECT TOP 30 *
FROM HouseData;

----------
-- DATE CLEANING
----------

SELECT SaleDate FROM HouseData;

-- Display-only conversion
SELECT CAST(SaleDate AS date)
FROM HouseData;

-- Inefficient / it wont work because it is not changing the type of the column 
/*UPDATE HouseData
SET SaleDate = CAST(SaleDate AS date);*/

-- Preferred approach
ALTER TABLE HouseData
ADD SaleDateConverted date;

UPDATE HouseData
SET SaleDateConverted = CAST(SaleDate AS date);

----------
-- FIX NULL PROPERTY ADDRESS
----------

SELECT *
FROM HouseData
WHERE PropertyAddress IS NULL;

-- Deterministic self-join update
UPDATE h1
SET h1.PropertyAddress = h2.PropertyAddress
FROM HouseData h1
JOIN (
    SELECT ParcelID, MAX(PropertyAddress) AS PropertyAddress
    FROM HouseData
    WHERE PropertyAddress IS NOT NULL
    GROUP BY ParcelID
) h2
ON h1.ParcelID = h2.ParcelID
WHERE h1.PropertyAddress IS NULL;

----------
-- SPLIT PROPERTY ADDRESS
----------
SELECT PropertyAddress
FROM HouseData
ORDER BY ParcelID;

--efficient method using PARSENAME
ALTER TABLE HouseData ADD PropertyAddressSeparated varchar(100);
ALTER TABLE HouseData ADD PropertyAddressCity varchar(50);

UPDATE HouseDATA
  SET 
    PropertyAddressSeparated = PARSENAME(REPLACE(PropertyAddress,',','.'),2),
    PropertyAddressCity = PARSENAME(REPLACE(PropertyAddress,',','.'),1)

-- Inefficient substring method
/*SELECT
    SUBSTRING(PropertyAddress,1,CHARINDEX(',',PropertyAddress)-1),
    SUBSTRING(PropertyAddress,CHARINDEX(',',PropertyAddress)+1,LEN(PropertyAddress))
FROM HouseData;

UPDATE HouseData
SET
    PropertyAddressSeparated = SUBSTRING(PropertyAddress,1,CHARINDEX(',',PropertyAddress)-1),
    PropertyAddressCity = SUBSTRING(PropertyAddress,
                                    CHARINDEX(',',PropertyAddress)+1,
                                    LEN(PropertyAddress))
WHERE PropertyAddress IS NOT NULL
  AND CHARINDEX(',',PropertyAddress) > 0;*/

----------
-- SPLIT OWNER ADDRESS
----------

SELECT OwnerAddress FROM HouseData;

-- Efficient PARSENAME method
SELECT
    PARSENAME(REPLACE(OwnerAddress,',','.'),3),
    PARSENAME(REPLACE(OwnerAddress,',','.'),2),
    PARSENAME(REPLACE(OwnerAddress,',','.'),1)
FROM HouseData;

ALTER TABLE HouseData ADD OwnerAddressSeparated varchar(255);
ALTER TABLE HouseData ADD OwnerAddressCity varchar(255);
ALTER TABLE HouseData ADD OwnerAddressState varchar(255);

UPDATE HouseData
SET
    OwnerAddressSeparated = PARSENAME(REPLACE(OwnerAddress,',','.'),3),
    OwnerAddressCity = PARSENAME(REPLACE(OwnerAddress,',','.'),2),
    OwnerAddressState = PARSENAME(REPLACE(OwnerAddress,',','.'),1)
WHERE OwnerAddress IS NOT NULL;

-- Inefficient nested SUBSTRING
/*SELECT OwnerAddress, 
  SUBSTRING(OwnerAddress,1,CHARINDEX(',',OwnerAddress)-1),
  SUBSTRING(
    SUBSTRING(
      OwnerAddress, 
      CHARINDEX(',',OwnerAddress)+1,LEN(OwnerAddress)),
    1,
    CHARINDEX(',',SUBSTRING(OwnerAddress, CHARINDEX(',',OwnerAddress)+1,LEN(OwnerAddress)))-1
  ),
  SUBSTRING(SUBSTRING(OwnerAddress, CHARINDEX(',',OwnerAddress)+1,LEN(OwnerAddress)),
  CHARINDEX(',',SUBSTRING(OwnerAddress, CHARINDEX(',',OwnerAddress)+1,LEN(OwnerAddress)))+1,
  LEN(SUBSTRING(OwnerAddress, CHARINDEX(',',OwnerAddress)+1,LEN(OwnerAddress))))
FROM HouseData*/



----------
-- NORMALIZE SoldAsVacant
----------

SELECT *
FROM HouseData
WHERE SoldAsVacant IN ('Y','N');

-- Inefficient multiple updates
/*UPDATE HouseData SET SoldAsVacant = 'Yes' WHERE SoldAsVacant = 'Y';
UPDATE HouseData SET SoldAsVacant = 'No'  WHERE SoldAsVacant = 'N';*/

-- Efficient CASE update
UPDATE HouseData
SET SoldAsVacant = CASE
    WHEN SoldAsVacant = 'Y' THEN 'Yes'
    WHEN SoldAsVacant = 'N' THEN 'No'
    ELSE SoldAsVacant
END;

----------
-- REMOVE DUPLICATES
----------

WITH DuplicateDetector AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY
                   ParcelID,
                   PropertyAddress,
                   SalePrice,
                   SaleDate,
                   LegalReference
               ORDER BY UniqueID
           ) AS RowNumber
    FROM HouseData
)
SELECT *
FROM DuplicateDetector
WHERE RowNumber > 1;

WITH DuplicateDetector AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY
                   ParcelID,
                   PropertyAddress,
                   SalePrice,
                   SaleDate,
                   LegalReference
               ORDER BY UniqueID
           ) AS RowNumber
    FROM HouseData
)
DELETE
FROM DuplicateDetector
WHERE RowNumber > 1;

----------
-- DROP UNUSED COLUMNS
----------

ALTER TABLE HouseData
DROP COLUMN OwnerAddress, TaxDistrict, PropertyAddress;

ALTER TABLE HouseData
DROP COLUMN SaleDate;

SELECT * FROM HouseData;
