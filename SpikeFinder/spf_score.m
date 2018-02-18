function score = spf_score(xest,xtrue)
% function score = spf_score(xest,xtrue)

if ~isvector(xest)
    n = size(xest,2);
    score = zeros(1,n);
    for i=1:n, score(i) = spf_score(xest(:,i),xtrue(:,i)); end
    return
end
    
ntc = find(~isnan(xtrue),1,'last');
xtrue = fn_bin(xtrue(1:ntc),4);
xest = fn_bin(xest(1:ntc),4);
c = corrcoef(xest,xtrue);
score = c(1,2);
