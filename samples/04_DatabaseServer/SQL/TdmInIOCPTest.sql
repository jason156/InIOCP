//
// InIOCP TInSQLManager ��Դ�ļ�(�ı���ʽ)
//

// ÿһ������Ϊһ�� SQL ���
//   ���Դ� Delphi �Ĳ���ָʾ���š�:������ʱ������������Ҫ����Ӧ�Ĳ����Ͳ���ֵ����
//   �����е���β�ַ�����Ϊ��[���͡�]����
//   ÿ���п���������ע�⡰//����

[Select_tbl_xzqh]

SELECT *
FROM tbl_xzqh

[Select_tbl_xzqh2]

SELECT code, detail
FROM tbl_xzqh
WHERE code<:code

[Select_tbl_xzqh4]

SELECT code, detail
FROM tbl_xzqh
WHERE detail=:detail

[Update_xzqh]

UPDATE tbl_xzqh SET code = 001 WHERE code IS NULL

[Stored_select]

SELECT * FROM tbl_xzqh WHERE code < '110105' ORDER BY code
